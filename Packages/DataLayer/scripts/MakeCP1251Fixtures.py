# Builds MP3 fixtures whose tags are Windows-1251 text mislabelled as Latin-1:
#   python3 MakeCP1251Fixtures.py <tagged.mp3> <cp1251-id3v2.mp3> <cp1251-id3v1.mp3>
# The audio frames come from <tagged.mp3>; its own ID3v2 tag is dropped.
import struct
import sys

source, output_v2, output_v1 = sys.argv[1:4]
data = open(source, "rb").read()
assert data[:3] == b"ID3"
size_bytes = data[6:10]
tag_size = (size_bytes[0] << 21) | (size_bytes[1] << 14) | (size_bytes[2] << 7) | size_bytes[3]
audio = data[10 + tag_size:]
if audio[-128:-125] == b"TAG":
    audio = audio[:-128]


def frame(frame_id, text):
    # Encoding byte 0 claims ISO-8859-1, but the text is Windows-1251.
    body = b"\x00" + text.encode("cp1251")
    return frame_id.encode() + struct.pack(">I", len(body)) + b"\x00\x00" + body


frames = frame("TIT2", "Любовь и Мир") + frame("TPE1", "Тимати") + frame("TALB", "Артем Меладзе") + frame("TRCK", "5")
n = len(frames)
syncsafe = bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F])
open(output_v2, "wb").write(b"ID3\x03\x00\x00" + syncsafe + frames + audio)


def field(text, length):
    encoded = text.encode("cp1251")[:length]
    return encoded + b"\x00" * (length - len(encoded))


# ID3v1.1: title, artist, album, year, comment, zero byte, track, genre.
v1 = b"TAG" + field("Звезда", 30) + field("Кино", 30) + field("Группа крови", 30) + b"1988" + field("", 28) + b"\x00\x07" + b"\xff"
assert len(v1) == 128
open(output_v1, "wb").write(audio + v1)
