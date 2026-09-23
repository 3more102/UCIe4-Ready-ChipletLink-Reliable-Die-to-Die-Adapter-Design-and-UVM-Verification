POLY = 0x04C11DB7
MASK32 = 0xFFFFFFFF
SEQ_MOD = 256


class RetryLimitExceeded(RuntimeError):
    """Raised when a flit exceeds the configured retry budget."""


def crc32_ucie_edu(data: int, seq: int, flit_w: int = 256, seq_w: int = 8) -> int:
    """Bit-accurate reference for the repository-defined educational CRC.

    This convention exists only to keep the RTL, smoke tests, and UVM reference
    model consistent. It is not a claim about the standardized UCIe wire CRC.
    """
    crc = MASK32
    for i in range(seq_w - 1, -1, -1):
        feedback = ((crc >> 31) & 1) ^ ((seq >> i) & 1)
        crc = (crc << 1) & MASK32
        if feedback:
            crc ^= POLY
    for i in range(flit_w - 1, -1, -1):
        feedback = ((crc >> 31) & 1) ^ ((data >> i) & 1)
        crc = (crc << 1) & MASK32
        if feedback:
            crc ^= POLY
    return (~crc) & MASK32


class ReliabilityModel:
    """Reference model for the reliable educational die-to-die link."""

    def __init__(
        self,
        depth=16,
        max_retries=3,
        duplicate_window=16,
        ack_timeout=64,
    ):
        if not 1 <= depth <= SEQ_MOD:
            raise ValueError("depth must be in [1, 256]")
        if max_retries < 0:
            raise ValueError("max_retries must be non-negative")
        if not 1 <= duplicate_window < SEQ_MOD:
            raise ValueError("duplicate_window must be in [1, 255]")
        if ack_timeout < 1:
            raise ValueError("ack_timeout must be positive")

        self.depth = depth
        self.max_retries = max_retries
        self.duplicate_window = duplicate_window
        self.ack_timeout = ack_timeout
        self.next_seq = 0
        self.expected_rx_seq = 0
        self.replay = {}
        self.retry_count = {}
        self.age = {}
        self.accepted_history = []

    def _allocate_seq(self) -> int:
        seq = self.next_seq
        for _ in range(SEQ_MOD):
            if seq not in self.replay:
                self.next_seq = (seq + 1) & 0xFF
                return seq
            seq = (seq + 1) & 0xFF
        raise BufferError("all sequence numbers are still outstanding")

    def send(self, data: int):
        if len(self.replay) >= self.depth:
            raise BufferError("replay buffer full")
        seq = self._allocate_seq()
        crc = crc32_ucie_edu(data, seq)
        self.replay[seq] = (data, crc)
        self.retry_count[seq] = 0
        self.age[seq] = 0
        return seq, data, crc

    def _remember_accepted(self, seq: int):
        self.accepted_history.insert(0, seq)
        del self.accepted_history[self.duplicate_window :]

    def receive(self, seq: int, data: int, crc: int):
        seq &= 0xFF
        if crc32_ucie_edu(data, seq) != crc:
            return {
                "ack": None,
                "retry": self.expected_rx_seq,
                "data": None,
                "duplicate": False,
                "sequence_error": False,
                "crc_error": True,
            }

        expected = self.expected_rx_seq
        if seq == expected:
            self.expected_rx_seq = (expected + 1) & 0xFF
            self._remember_accepted(seq)
            return {
                "ack": seq,
                "retry": None,
                "data": data,
                "duplicate": False,
                "sequence_error": False,
                "crc_error": False,
            }

        if seq in self.accepted_history:
            return {
                "ack": seq,
                "retry": None,
                "data": None,
                "duplicate": True,
                "sequence_error": False,
                "crc_error": False,
            }

        return {
            "ack": None,
            "retry": expected,
            "data": None,
            "duplicate": False,
            "sequence_error": True,
            "crc_error": False,
        }

    def ack(self, seq: int) -> bool:
        existed = seq in self.replay
        self.replay.pop(seq, None)
        self.retry_count.pop(seq, None)
        self.age.pop(seq, None)
        return existed

    def retry(self, seq: int):
        if seq not in self.replay:
            raise KeyError(seq)
        count = self.retry_count[seq] + 1
        if count > self.max_retries:
            raise RetryLimitExceeded(
                f"sequence {seq} exceeded retry budget {self.max_retries}"
            )
        self.retry_count[seq] = count
        self.age[seq] = 0
        data, crc = self.replay[seq]
        return seq, data, crc

    def tick(self, cycles: int = 1):
        """Advance ACK timers and return the oldest timed-out sequence, if any."""
        if cycles < 0:
            raise ValueError("cycles must be non-negative")
        for _ in range(cycles):
            for seq in tuple(self.age):
                self.age[seq] += 1

        for seq in self.replay:
            if self.age[seq] >= self.ack_timeout:
                return seq
        return None

    def administrative_flush(self):
        """Model link-disable semantics: discard outstanding reliability state."""
        self.next_seq = 0
        self.expected_rx_seq = 0
        self.replay.clear()
        self.retry_count.clear()
        self.age.clear()
        self.accepted_history.clear()
