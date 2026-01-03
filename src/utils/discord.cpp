#include <iostream>
#include "../core/globals.h"
#include "crashlog.h"
#include "discord_rpc.h"

void Discord_Ready(const DiscordUser* user) {
    std::cout << "[DISCORD]: Connected to Discord user: " + std::string(user->username);
}

void Discord_Disconnected(int errorCode, const char* message) {
    std::cout << "[DISCORD]: Disconnected (" + std::to_string(errorCode) + "): " + std::string(message);
}

void Discord_Error(int errorCode, const char* message) {
    std::cout << "[DISCORD]: Error (" + std::to_string(errorCode) + "): " + std::string(message);
    AppendToCrashLog("[DISCORD]: Error (" + std::to_string(errorCode) + "): " + std::string(message));
}

void InitializeDiscord()
{
    DiscordEventHandlers handlers{};
    memset(&handlers, 0, sizeof(handlers));
    handlers.ready = Discord_Ready;
    handlers.disconnected = Discord_Disconnected;
    handlers.errored = Discord_Error;

    Discord_Initialize("1361448446862692492", &handlers, 1, nullptr);
}

// Encapsulated presence setters

static void SetDiscordWatchingPresence(
        const std::vector<std::string>& args
) {
    // expects:
    // 0: generic "watching" identifier
    // 1: type (movie, series)
    // 2: title
    // 3: season
    // 4: episode
    // 5: episode name
    // 6: episode thumbnail (small image) (Optional)
    // 7: show/movie image (large image)
    // 8: elapsed seconds
    // 9: duration seconds
    // 10: isPaused ("yes" or "no") (Optional)
    // 11: more detail button link (imdb link) (Optional)
    // 12: watch on stremio button link (stremio link) (Optional)
    DiscordRichPresence discordPresence{};
    memset(&discordPresence, 0, sizeof(discordPresence));

    discordPresence.statusDisplayType = DISCORD_STATUS_DISPLAY_TYPE_DETAILS;
    discordPresence.type = DISCORD_ACTIVITY_TYPE_WATCHING;

    // Common fields (required)
    discordPresence.details = args[2].c_str(); // Title
    discordPresence.largeImageKey = args[7].c_str();
    discordPresence.largeImageText = args[2].c_str();

    // Handle paused state (optional)
    bool isPaused = (!args[10].empty() && args[10] == "yes");

    if (isPaused) {
        discordPresence.state = "Paused";
        discordPresence.startTimestamp = 0;
        discordPresence.endTimestamp = 0;
    } else {
        std::time_t currentTime = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        int elapsedSeconds = std::stoi(args[8]);
        int durationSeconds = std::stoi(args[9]);

        discordPresence.startTimestamp = currentTime - elapsedSeconds;
        discordPresence.endTimestamp = currentTime + (durationSeconds - elapsedSeconds);

        if (args[1] == "series") {
            // Series-specific fields
            std::string state = args[5] + " (S" + args[3] + "-E" + args[4] + ")";
            discordPresence.state = state.c_str();

            if (!args[6].empty()) {
                discordPresence.smallImageKey = args[6].c_str();
                discordPresence.smallImageText = args[5].c_str();
            }
        } else {
            discordPresence.state = "Enjoying a Movie";
        }
    }

    // Buttons setup (optional)
    if (!args[11].empty()) {
        discordPresence.button1Label = "More Details";
        discordPresence.button1Url = args[11].c_str();
    }

    if (!args[12].empty()) {
        discordPresence.button2Label = "Watch on Stremio";
        discordPresence.button2Url = args[12].c_str();
    }

    Discord_UpdatePresence(&discordPresence);
}

static void SetDiscordMetaDetailPresence(const std::vector<std::string>& args) {
    // args structure:
    // 0: embed type ("meta-detail")
    // 1: type ("movie" or "series")
    // 2: title
    // 3: image URL

    DiscordRichPresence discordPresence{};
    memset(&discordPresence, 0, sizeof(discordPresence));
    discordPresence.statusDisplayType = DISCORD_STATUS_DISPLAY_TYPE_DETAILS;
    discordPresence.type = DISCORD_ACTIVITY_TYPE_WATCHING;
    discordPresence.details = args[2].c_str(); // Title (show/movie)
    discordPresence.largeImageKey = args[3].c_str();
    discordPresence.largeImageText = args[2].c_str();

    // Engaging state
    discordPresence.state = args[1] == "movie"
                            ? "Exploring a Movie"
                            : "Exploring a Series";

    Discord_UpdatePresence(&discordPresence);
}

static void SetDiscordDiscoverPresence(const char *const details, const char *const state) {
    std::cout << "[DISCORD]: Setting discover Presence";

    DiscordRichPresence discordPresence{};
    memset(&discordPresence, 0, sizeof(discordPresence));
    discordPresence.statusDisplayType = DISCORD_STATUS_DISPLAY_TYPE_STATE;
    discordPresence.type = DISCORD_ACTIVITY_TYPE_WATCHING;
    discordPresence.state = state;
    discordPresence.details = details;
    discordPresence.largeImageKey = "https://raw.githubusercontent.com/Stremio/stremio-web/refs/heads/development/images/icon.png";
    discordPresence.largeImageText = "Stremio";
    Discord_UpdatePresence(&discordPresence);
}

void SetDiscordPresenceFromArgs(const std::vector<std::string>& args) {
    if (!g_isRpcOn || args.empty()) {
        return;
    }

    const std::string& embedType = args[0];
    if (embedType == "watching" && args.size() >= 12) {
        SetDiscordWatchingPresence(args);
    } else if (embedType == "meta-detail" && args.size() >= 4) {
        SetDiscordMetaDetailPresence(args);
    } else if (embedType == "board") {
        SetDiscordDiscoverPresence("Resuming Favorites", "On Board");
    } else if (embedType == "discover") {
        SetDiscordDiscoverPresence("Finding New Gems", "In Discover");
    } else if (embedType == "library") {
        SetDiscordDiscoverPresence("Revisiting Old Favorites", "In Library");
    } else if (embedType == "calendar") {
        SetDiscordDiscoverPresence("Planning My Next Binge", "On Calendar");
    } else if (embedType == "addons") {
        SetDiscordDiscoverPresence("Exploring Add-ons", "In Add-ons");
    } else if (embedType == "settings") {
        SetDiscordDiscoverPresence("Tuning Preferences", "In Settings");
    } else if (embedType == "search") {
        SetDiscordDiscoverPresence("Searching for Shows & Movies", "In Search");
    } else if (embedType == "clear") {
        Discord_ClearPresence();
    }
    // Add more presence types here...
}
