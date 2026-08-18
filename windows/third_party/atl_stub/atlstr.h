// Minimal ATL string conversion stub for environments without ATL/MFC.
// Used by flutter_secure_storage_windows (CA2W / CW2A).
#pragma once

#include <windows.h>

#include <string>

class CA2W {
 public:
  LPWSTR m_psz = nullptr;

  explicit CA2W(const char* psz, UINT codePage = CP_UTF8) {
    if (psz == nullptr || psz[0] == '\0') {
      return;
    }
    const int length = MultiByteToWideChar(codePage, 0, psz, -1, nullptr, 0);
    if (length > 0) {
      buffer_.resize(static_cast<size_t>(length));
      MultiByteToWideChar(codePage, 0, psz, -1, buffer_.data(), length);
      m_psz = buffer_.data();
    }
  }

  operator LPCWSTR() const { return m_psz == nullptr ? L"" : m_psz; }

 private:
  std::wstring buffer_;
};

class CW2A {
 public:
  LPSTR m_psz = nullptr;

  explicit CW2A(const wchar_t* psz, UINT codePage = CP_UTF8) {
    if (psz == nullptr || psz[0] == L'\0') {
      return;
    }
    const int length =
        WideCharToMultiByte(codePage, 0, psz, -1, nullptr, 0, nullptr, nullptr);
    if (length > 0) {
      buffer_.resize(static_cast<size_t>(length));
      WideCharToMultiByte(
          codePage, 0, psz, -1, buffer_.data(), length, nullptr, nullptr);
      m_psz = buffer_.data();
    }
  }

  operator const char*() const { return m_psz == nullptr ? "" : m_psz; }

 private:
  std::string buffer_;
};
