#ifndef AUDIO_H
#define AUDIO_H

#include "miniaudio.h"
#include <string>
#include <unordered_map>

// Global audio engine instance
extern ma_engine engine;

ma_result initializeAudioEngine();
void playSound(const std::string &soundFile);
void setVolume(float volume);
void runMainLoop(const std::string &devicePath,
                 const std::unordered_map<int, std::string> &keySoundMap, float volume,
                 const std::string &soundpackPath);

#endif // AUDIO_H
