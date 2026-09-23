import pytest

from model.ucie_model import ReliabilityModel, RetryLimitExceeded, crc32_ucie_edu


def test_crc_is_deterministic_and_data_sensitive():
    data = int("0123456789abcdef" * 4, 16)
    c0 = crc32_ucie_edu(data, 0)
    assert c0 == crc32_ucie_edu(data, 0)
    assert c0 != crc32_ucie_edu(data ^ 1, 0)
    assert c0 != crc32_ucie_edu(data, 1)


def test_error_detect_retry_replay_ack():
    m = ReliabilityModel(depth=4)
    payload = int("deadbeef" * 8, 16)
    seq, data, crc = m.send(payload)
    bad = m.receive(seq, data ^ 1, crc)
    assert bad["ack"] is None
    assert bad["retry"] == seq
    assert bad["data"] is None
    assert bad["crc_error"]
    rseq, rdata, rcrc = m.retry(seq)
    assert (rseq, rdata, rcrc) == (seq, data, crc)
    good = m.receive(rseq, rdata, rcrc)
    assert good["ack"] == seq
    assert good["retry"] is None
    assert good["data"] == payload
    assert m.ack(seq)
    assert seq not in m.replay


def test_replay_capacity():
    m = ReliabilityModel(depth=2)
    m.send(1)
    m.send(2)
    with pytest.raises(BufferError):
        m.send(3)


def test_selective_ack_frees_capacity_without_overwriting_live_entry():
    m = ReliabilityModel(depth=4)
    packets = [m.send(i) for i in range(4)]
    live_seq0 = packets[0][0]
    assert m.ack(packets[1][0])
    new_packet = m.send(99)
    assert live_seq0 in m.replay
    assert m.replay[live_seq0][0] == 0
    assert new_packet[0] != live_seq0


def test_sequence_allocator_skips_live_sequence_after_wrap():
    m = ReliabilityModel(depth=4)
    first = m.send(0xA5)
    assert first[0] == 0
    m.next_seq = 0
    second = m.send(0x5A)
    assert second[0] == 1
    assert m.replay[0][0] == 0xA5


def test_duplicate_is_reacked_but_not_redelivered():
    m = ReliabilityModel()
    seq, data, crc = m.send(0x1234)
    first = m.receive(seq, data, crc)
    duplicate = m.receive(seq, data, crc)
    assert first["data"] == data
    assert duplicate["ack"] == seq
    assert duplicate["data"] is None
    assert duplicate["duplicate"]


def test_out_of_order_flit_requests_expected_sequence():
    m = ReliabilityModel()
    seq0, data0, crc0 = m.send(0x10)
    seq1, data1, crc1 = m.send(0x11)
    assert seq0 == 0 and seq1 == 1
    gap = m.receive(seq1, data1, crc1)
    assert gap["ack"] is None
    assert gap["retry"] == seq0
    assert gap["sequence_error"]
    good0 = m.receive(seq0, data0, crc0)
    good1 = m.receive(seq1, data1, crc1)
    assert good0["data"] == data0
    assert good1["data"] == data1


def test_receive_sequence_wrap():
    m = ReliabilityModel()
    m.expected_rx_seq = 0xFF
    data_ff = 0xCAFE
    crc_ff = crc32_ucie_edu(data_ff, 0xFF)
    data_00 = 0xBEEF
    crc_00 = crc32_ucie_edu(data_00, 0x00)
    assert m.receive(0xFF, data_ff, crc_ff)["data"] == data_ff
    assert m.expected_rx_seq == 0
    assert m.receive(0x00, data_00, crc_00)["data"] == data_00
    assert m.expected_rx_seq == 1


def test_retry_budget_exhaustion():
    m = ReliabilityModel(max_retries=2)
    seq, _, _ = m.send(0x44)
    m.retry(seq)
    m.retry(seq)
    with pytest.raises(RetryLimitExceeded):
        m.retry(seq)


def test_ack_unknown_sequence_is_non_destructive():
    m = ReliabilityModel()
    seq, data, _ = m.send(0x55)
    assert not m.ack((seq + 7) & 0xFF)
    assert m.replay[seq][0] == data


def test_retry_unknown_sequence_raises():
    m = ReliabilityModel()
    with pytest.raises(KeyError):
        m.retry(77)


def test_constructor_rejects_invalid_configuration():
    with pytest.raises(ValueError):
        ReliabilityModel(depth=0)
    with pytest.raises(ValueError):
        ReliabilityModel(depth=257)
    with pytest.raises(ValueError):
        ReliabilityModel(max_retries=-1)
    with pytest.raises(ValueError):
        ReliabilityModel(duplicate_window=0)
    with pytest.raises(ValueError):
        ReliabilityModel(ack_timeout=0)


def test_ack_timeout_rearms_after_each_replay_then_exhausts_budget():
    m = ReliabilityModel(max_retries=2, ack_timeout=3)
    seq, data, crc = m.send(0xA55A)

    assert m.tick(2) is None
    assert m.tick() == seq
    assert m.retry(seq) == (seq, data, crc)

    assert m.tick(3) == seq
    assert m.retry(seq) == (seq, data, crc)

    assert m.tick(3) == seq
    with pytest.raises(RetryLimitExceeded):
        m.retry(seq)


def test_administrative_flush_resets_reliability_epoch():
    m = ReliabilityModel(depth=4, ack_timeout=2)
    seq, _, _ = m.send(0x123)
    assert seq in m.replay
    assert m.tick(2) == seq
    m.administrative_flush()
    assert m.replay == {}
    assert m.retry_count == {}
    assert m.age == {}
    assert m.next_seq == 0
    assert m.expected_rx_seq == 0
    assert m.send(0x456)[0] == 0
