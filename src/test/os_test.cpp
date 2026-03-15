#include "test.h"

#include <base/os.h>

#include <gtest/gtest.h>

TEST(Os, VersionStr)
{
	char aVersion[128];
	ASSERT_TRUE(os_version_str(aVersion, sizeof(aVersion)));
	EXPECT_STRNE(aVersion, "");
}

TEST(Os, LocaleStr)
{
	char aLocale[128];
	os_locale_str(aLocale, sizeof(aLocale));
	EXPECT_STRNE(aLocale, "");
}

TEST(Os, MemoryUsage)
{
	std::optional<CMemoryUsageInfo> MemoryUsage = os_memory_usage();
	if(MemoryUsage.has_value())
	{
		EXPECT_GT(MemoryUsage.value().m_UsedBytes, 0);
		EXPECT_GT(MemoryUsage.value().m_TotalBytes, 0);
		EXPECT_LE(MemoryUsage.value().m_UsedBytes, MemoryUsage.value().m_TotalBytes);
	}
}
