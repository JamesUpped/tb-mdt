import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { BOLORecord } from '@/types'

export const useBoloStore = defineStore('bolo', () => {
  const bolos = ref<BOLORecord[]>([])
  const loading = ref(false)

  function setBolos(data: BOLORecord[]) {
    bolos.value = data
  }

  async function create(payload: Partial<BOLORecord>) {
    loading.value = true
    try {
      return await fetchNui<{ success: boolean }>('createBOLO', payload as Record<string, unknown>)
    } finally {
      loading.value = false
    }
  }

  async function deactivate(boloId: number) {
    return fetchNui<{ success: boolean }>('deactivateBOLO', { boloId })
  }

  return { bolos, loading, setBolos, create, deactivate }
})
