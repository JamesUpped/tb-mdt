import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { Officer } from '@/types'

export const useRosterStore = defineStore('roster', () => {
  const roster = ref<Officer[]>([])
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      roster.value = await fetchNui<Officer[]>('getRoster')
    } finally {
      loading.value = false
    }
  }

  async function setCallsign(citizenid: string, callsign: string) {
    const result = await fetchNui<{ success: boolean; error?: string }>('setCallsign', { citizenid, callsign })
    if (result.success) {
      const officer = roster.value.find(o => o.citizenid === citizenid)
      if (officer) officer.callsign = callsign
    }
    return result
  }

  return { roster, loading, load, setCallsign }
})
