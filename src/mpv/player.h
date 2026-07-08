#ifndef PLAYER_H
#define PLAYER_H

#include <string>
#include <vector>
#include <windows.h>
#include "nlohmann/json.hpp"

bool InitMPV(HWND hwnd);
void CleanupMPV();
void ResendChapterData();
void HandleMpvEvents();

// Commands
void HandleMpvCommand(const std::vector<std::string>& args);
void HandleMpvSetProp(const std::vector<std::string>& args);
void HandleMpvObserveProp(const std::vector<std::string>& args);

// For pausing
void pauseMPV(bool allowed);

#endif // PLAYER_H
