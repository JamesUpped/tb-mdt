import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { WeaponRecord } from '@/types'

export const useWeaponStore = defineStore('weapon', () => {
  const weapons = ref<WeaponRecord[]>([])
  const loading = ref(false)

  async function search(query: string) {
    loading.value = true
    try {
      weapons.value = await fetchNui<WeaponRecord[]>('searchWeapons', { query })
    } finally {
      loading.value = false
    }
  }

  async function register(data: { serial: string; model: string; ownerCid?: string; ownerName?: string; notes?: string }) {
    const result = await fetchNui<{ success: boolean; weapon?: WeaponRecord; error?: string }>('registerWeapon', data)
    if (result.success && result.weapon) {
      weapons.value.unshift(result.weapon)
    }
    return result
  }

  async function updateStatus(weaponId: number, status: WeaponRecord['status'], notes?: string) {
    const result = await fetchNui<{ success: boolean }>('updateWeaponStatus', { weaponId, status, notes })
    if (result.success) {
      const weapon = weapons.value.find(w => w.id === weaponId)
      if (weapon) {
        weapon.status = status
        if (notes !== undefined) weapon.notes = notes
      }
    }
    return result
  }

  return { weapons, loading, search, register, updateStatus }
})
