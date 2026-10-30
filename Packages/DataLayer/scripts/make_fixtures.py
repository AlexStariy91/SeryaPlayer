"""Helpers for make_fixtures.sh: a tiny PNG, a silent tagged MP3, Vorbis comments for FLAC."""
import struct
import sys
import zlib

TAGS = {
    "title": "Тестовая песня",
    "artist": "Fixture Artist",
    "album": "Fixture Album",
    "album_artist": "Fixture Band",
    "track": "3/12",
}


def png(path):
    width = height = 64
    rows = b"".join(b"\x00" + b"".join(bytes((x * 4, y * 4, 128)) for x in range(width)) for y in range(height))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)


def mp3(cover_path, path):
    def text_frame(frame_id, value):
        payload = b"\x01" + "﻿".encode("utf-16-le") + value.encode("utf-16-le")
        return frame_id.encode() + struct.pack(">I", len(payload)) + b"\x00\x00" + payload

    cover = open(cover_path, "rb").read()
    apic = b"\x00" + b"image/png\x00" + b"\x03" + b"\x00" + cover
    frames = b"".join([
        text_frame("TIT2", TAGS["title"]),
        text_frame("TPE1", TAGS["artist"]),
        text_frame("TALB", TAGS["album"]),
        text_frame("TPE2", TAGS["album_artist"]),
        text_frame("TRCK", TAGS["track"]),
        b"APIC" + struct.pack(">I", len(apic)) + b"\x00\x00" + apic,
    ])
    size = len(frames)
    syncsafe = bytes(((size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F))
    tag = b"ID3\x03\x00\x00" + syncsafe + frames
    # MPEG-1 Layer III, 32 kbps, 44.1 kHz, mono, no CRC: 104-byte frames. All-zero side info
    # and main data decode as silence. 77 frames ≈ 2 s.
    frame = b"\xff\xfb\x10\xc0" + bytes(100)
    open(path, "wb").write(tag + frame * 77)


def flac(source, cover_path, path):
    data = open(source, "rb").read()
    assert data[:4] == b"fLaC"
    pos, blocks = 4, []
    while True:
        header = data[pos]
        length = int.from_bytes(data[pos + 1:pos + 4], "big")
        block_type = header & 0x7F
        if block_type != 4:
            blocks.append((block_type, data[pos + 4:pos + 4 + length]))
        pos += 4 + length
        if header & 0x80:
            break
    vendor = b"SeryaPlayer fixtures"
    comments = [f"TITLE={TAGS['title']}", f"ARTIST={TAGS['artist']}", f"ALBUM={TAGS['album']}",
                f"ALBUMARTIST={TAGS['album_artist']}", "TRACKNUMBER=3"]
    vorbis = struct.pack("<I", len(vendor)) + vendor + struct.pack("<I", len(comments))
    for comment in comments:
        encoded = comment.encode()
        vorbis += struct.pack("<I", len(encoded)) + encoded
    blocks.insert(1, (4, vorbis))
    cover = open(cover_path, "rb").read()
    mime, description = b"image/png", b"Cover"
    picture = struct.pack(">II", 3, len(mime)) + mime + struct.pack(">I", len(description)) + description
    picture += struct.pack(">IIIII", 64, 64, 24, 0, len(cover)) + cover
    blocks.insert(2, (6, picture))
    out = b"fLaC"
    for index, (block_type, body) in enumerate(blocks):
        last = 0x80 if index == len(blocks) - 1 else 0
        out += bytes((last | block_type,)) + len(body).to_bytes(3, "big") + body
    open(path, "wb").write(out + data[pos:])


if __name__ == "__main__":
    command = sys.argv[1]
    if command == "artwork":
        png(sys.argv[2])
    elif command == "mp3":
        mp3(sys.argv[2], sys.argv[3])
    elif command == "flac":
        flac(sys.argv[2], sys.argv[3], sys.argv[4])
