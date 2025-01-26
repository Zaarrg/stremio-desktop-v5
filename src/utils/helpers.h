#ifndef HELPERS_H
#define HELPERS_H

#include <windows.h>
#include <string>
#include <vector>
#include <filesystem>

std::string WStringToUtf8(const std::wstring &wstr);
std::wstring Utf8ToWstring(const std::string& utf8Str);
std::string decodeURIComponent(const std::string& encoded);
std::wstring GetExeDirectory();
bool FileExists(const std::wstring& path);
bool DirectoryExists(const std::wstring& dirPath);
bool IsDuplicateProcessRunning(const std::vector<std::wstring>& targetProcesses);
bool isSubtitle(const std::wstring& filePath);

#endif // HELPERS_H