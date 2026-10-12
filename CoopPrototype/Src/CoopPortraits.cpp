#include "ModMain.h"

// The player list and the model picker draw a filled square where a portrait would go: this mod ships no pictures of the game's characters.
// A texture is only ever made here if a portrait is supplied at run time, which nothing does yet.

void ModMain::EnsurePlayerPortraitTextures()
{
    m_playerPortraitTexturesLoaded = true;
}

void ModMain::ReleasePlayerPortraitTextures()
{
    for (auto& texture : m_playerPortraitTextures)
        texture = nullptr;
    m_playerPortraitTexturesLoaded = false;
}

ITexture* ModMain::GetPlayerPortraitTexture(size_t index) const
{
    return index < m_playerPortraitTextures.size() ? m_playerPortraitTextures[index].get() : nullptr;
}
