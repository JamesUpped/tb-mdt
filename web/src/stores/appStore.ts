import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { PlayerInfo, MDTConfig, MDTView } from '@/types'

export const useAppStore = defineStore('app', () => {
  const isOpen = ref(false)
  const currentView = ref<MDTView>('dashboard')
  const player = ref<PlayerInfo | null>(null)
  const config = ref<MDTConfig | null>(null)

  function open(playerData: PlayerInfo, configData: MDTConfig) {
    player.value = playerData
    config.value = configData
    isOpen.value = true
    currentView.value = 'dashboard'
  }

  function close() {
    isOpen.value = false
  }

  function setView(view: MDTView) {
    currentView.value = view
  }

  function hasPermission(feature: string): boolean {
    return Boolean(player.value?.permissions?.[feature])
  }

  /** Grade-aware permission check mirroring server HasPermission(). */
  function can(feature: string, action?: string): boolean {
    const perms = player.value?.permissions?.[feature]
    const grade = player.value?.gradeLevel ?? 0
    if (perms === undefined || perms === null) return false
    if (typeof perms === 'boolean') return perms
    if (typeof perms === 'number') return grade >= perms
    if (typeof perms === 'object') {
      if (!action) return true
      const req = (perms as Record<string, boolean | number>)[action]
      if (typeof req === 'boolean') return req
      if (typeof req === 'number') return grade >= req
      return false
    }
    return false
  }

  return { isOpen, currentView, player, config, open, close, setView, hasPermission, can }
})
