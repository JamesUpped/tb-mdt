import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { WarrantRecord } from '@/types'

export const useWarrantStore = defineStore('warrant', () => {
  const warrants = ref<WarrantRecord[]>([])
  const loading = ref(false)

  function setWarrants(data: WarrantRecord[]) {
    warrants.value = data
  }

  async function issue(payload: Partial<WarrantRecord>) {
    loading.value = true
    try {
      return await fetchNui<{ success: boolean }>('issueWarrant', payload as Record<string, unknown>)
    } finally {
      loading.value = false
    }
  }

  async function execute(warrantId: number) {
    return fetchNui<{ success: boolean }>('executeWarrant', { warrantId })
  }

  return { warrants, loading, setWarrants, issue, execute }
})
