#include "test.h"
#include <gtest/gtest.h>

#include <base/system.h>
#include <engine/shared/network.h>

// TODO: test other split value
static void TestPack(const CNetChunkHeader &Header, std::initializer_list<unsigned char> Packed)
{
	unsigned char aData[8];
	ASSERT_LE(Packed.size(), std::size(aData));
	unsigned char *pData = &aData[0];
	const int BytesWritten = Header.Pack(pData) - pData;
	ASSERT_EQ(BytesWritten, Packed.size());

	const unsigned char *pPacked = Packed.begin();
	for(size_t i = 0; i < Packed.size(); ++i)
	{
		EXPECT_EQ(pData[i], pPacked[i]);
	}
}

TEST(ChunkHeader, PackZeroed)
{
	CNetChunkHeader Header;
	Header.m_Flags = 0;
	Header.m_Size = 0;
	Header.m_Sequence = 0;
	TestPack(Header, {0x00, 0x00});
}

TEST(ChunkHeader, PackFlagVital)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = 0;
	TestPack(Header, {0x40, 0x00, 0x00});
}

TEST(ChunkHeader, PackFlagResend)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_RESEND;
	Header.m_Size = 0;
	Header.m_Sequence = 0;
	TestPack(Header, {0x80, 0x00});
}

TEST(ChunkHeader, PackFlagVitalResend)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL | NET_CHUNKFLAG_RESEND;
	Header.m_Size = 0;
	Header.m_Sequence = 0;
	TestPack(Header, {0xC0, 0x00, 0x00});
}

TEST(ChunkHeader, PackSize15)
{
	CNetChunkHeader Header;
	Header.m_Flags = 0;
	Header.m_Size = 15;
	Header.m_Sequence = 0;
	TestPack(Header, {0x00, 0x0F});
}

TEST(ChunkHeader, PackSize255)
{
	CNetChunkHeader Header;
	Header.m_Flags = 0;
	Header.m_Size = 255;
	Header.m_Sequence = 0;
	TestPack(Header, {0x0F, 0x0F});
}

TEST(ChunkHeader, PackSize511)
{
	CNetChunkHeader Header;
	Header.m_Flags = 0;
	Header.m_Size = 511;
	Header.m_Sequence = 0;
	TestPack(Header, {0x1F, 0x0F});
}

TEST(ChunkHeader, PackSize1023)
{
	CNetChunkHeader Header;
	Header.m_Flags = 0;
	Header.m_Size = 1023;
	Header.m_Sequence = 0;
	TestPack(Header, {0x3F, 0x0F});
}

TEST(ChunkHeader, PackSizeAllBits)
{
	CNetChunkHeader Header;
	Header.m_Flags = 0;
	Header.m_Size = -1; // all bits set
	Header.m_Sequence = 0;
	TestPack(Header, {0x3F, 0x0F});
}

TEST(ChunkHeader, PackSeq5)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = 5;
	TestPack(Header, {0x40, 0x00, 0x05});
}

TEST(ChunkHeader, PackSeq63)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = 63;
	TestPack(Header, {0x40, 0x00, 0x3f});
}

TEST(ChunkHeader, PackSeq64)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = 64;
	TestPack(Header, {0x40, 0x00, 0x40});
}

TEST(ChunkHeader, PackSeq126)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = 126;
	TestPack(Header, {0x40, 0x00, 0x7E});
}

TEST(ChunkHeader, PackSeq255)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = 255;
	TestPack(Header, {0x40, 0x00, 0xFF});
}

TEST(ChunkHeader, PackSeqMax)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 0;
	Header.m_Sequence = NET_MAX_SEQUENCE - 1;
	TestPack(Header, {0x40, 0xC0, 0xFF});
}

TEST(ChunkHeader, PackSize255Seq511)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL;
	Header.m_Size = 255;
	Header.m_Sequence = 511;
	TestPack(Header, {0x4F, 0x4F, 0xFF});
}

TEST(ChunkHeader, PackAllBits)
{
	CNetChunkHeader Header;
	Header.m_Flags = NET_CHUNKFLAG_VITAL | NET_CHUNKFLAG_RESEND;
	Header.m_Size = -1; // all bits set
	Header.m_Sequence = NET_MAX_SEQUENCE - 1;
	// Packing with Split=4 leaves 2 bits unused
	TestPack(Header, {0xFF, 0xCF, 0xFF});
}
