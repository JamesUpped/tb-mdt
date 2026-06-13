import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { Officer } from '@/types'

export const useOfficerStore = defineStore('officer', () => {
  const officers = ref<Officer[]>([])

  function setOfficers(data: Officer[]) {
    officers.value = data
  }

  async function updateStatus(status: Officer['status']) {
    return fetchNui('updateStatus', { status })
  }

  return { officers, setOfficers, updateStatus }
})
