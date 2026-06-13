import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { AnnouncementRecord } from '@/types'

export const useAnnouncementStore = defineStore('announcement', () => {
  const announcements = ref<AnnouncementRecord[]>([])
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      announcements.value = await fetchNui<AnnouncementRecord[]>('getAnnouncements')
    } finally {
      loading.value = false
    }
  }

  async function create(data: { title: string; body: string; priority: AnnouncementRecord['priority'] }) {
    const result = await fetchNui<{ success: boolean; announcement?: AnnouncementRecord; error?: string }>('createAnnouncement', data)
    if (result.success && result.announcement) {
      announcements.value.unshift(result.announcement)
    }
    return result
  }

  async function remove(id: number) {
    const result = await fetchNui<{ success: boolean }>('deleteAnnouncement', { id })
    if (result.success) {
      announcements.value = announcements.value.filter(a => a.id !== id)
    }
    return result
  }

  /** Real-time push from another officer's create. */
  function push(announcement: AnnouncementRecord) {
    if (!announcements.value.some(a => a.id === announcement.id)) {
      announcements.value.unshift(announcement)
    }
  }

  return { announcements, loading, load, create, remove, push }
})
