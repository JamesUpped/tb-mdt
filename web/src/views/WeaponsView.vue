<template>
  <div class="space-y-4">
    <!-- Search + register -->
    <div class="flex items-center gap-3">
      <div class="relative flex-1">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input
          v-model="query"
          placeholder="Search by serial, owner, or weapon model..."
          class="w-full text-sm bg-input border border-border rounded-lg pl-10 pr-4 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground"
          @keydown.enter="doSearch"
        />
      </div>
      <button
        class="text-sm bg-primary text-primary-foreground px-4 py-2 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        :disabled="weaponStore.loading"
        @click="doSearch"
      >Search</button>
      <button
        v-if="appStore.can('weapons', 'register')"
        class="text-sm bg-secondary text-foreground px-4 py-2 rounded-lg font-medium hover:bg-secondary/70 transition-colors flex items-center gap-1.5"
        @click="showRegister = true"
      >
        <Plus class="w-4 h-4" /> Register
      </button>
    </div>

    <!-- Weapon list -->
    <div v-if="weaponStore.weapons.length > 0" class="space-y-2">
      <div
        v-for="weapon in weaponStore.weapons"
        :key="weapon.id"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border"
        :class="weapon.status === 'stolen' ? 'border-red-500/40' : ''"
      >
        <div class="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center shrink-0">
          <Crosshair class="w-5 h-5" :class="statusIcon[weapon.status]" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground">{{ weapon.serial }} · {{ weapon.model }}</p>
          <p class="text-xs text-muted-foreground truncate">
            Owner: {{ weapon.owner_name || 'Unregistered' }}
            <template v-if="weapon.notes"> · {{ weapon.notes }}</template>
          </p>
        </div>
        <span class="text-[10px] px-2 py-0.5 rounded-full capitalize font-medium" :class="statusBadge[weapon.status]">{{ weapon.status }}</span>
        <div v-if="appStore.can('weapons', 'flag')" class="flex gap-1">
          <button
            v-if="weapon.status !== 'stolen'"
            title="Flag stolen"
            class="text-[10px] px-2 py-1 rounded-lg bg-red-500/15 text-red-400 border border-red-500/30 hover:bg-red-500/25 transition-colors"
            @click="weaponStore.updateStatus(weapon.id, 'stolen')"
          >Stolen</button>
          <button
            v-if="weapon.status !== 'seized'"
            title="Mark seized"
            class="text-[10px] px-2 py-1 rounded-lg bg-yellow-500/15 text-yellow-400 border border-yellow-500/30 hover:bg-yellow-500/25 transition-colors"
            @click="weaponStore.updateStatus(weapon.id, 'seized')"
          >Seize</button>
          <button
            v-if="weapon.status !== 'registered'"
            title="Restore to registered"
            class="text-[10px] px-2 py-1 rounded-lg bg-green-500/15 text-green-400 border border-green-500/30 hover:bg-green-500/25 transition-colors"
            @click="weaponStore.updateStatus(weapon.id, 'registered')"
          >Clear</button>
        </div>
      </div>
    </div>

    <!-- Empty state -->
    <div v-else-if="!weaponStore.loading" class="text-center py-12">
      <Crosshair class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
      <p class="text-sm text-muted-foreground">Search the weapons registry, or register a new firearm</p>
    </div>

    <!-- Register modal -->
    <div v-if="showRegister" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60" @click.self="showRegister = false">
      <div class="w-[440px] rounded-xl bg-card border border-border shadow-2xl p-5 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="text-base font-semibold text-foreground">Register Weapon</h2>
          <button class="text-muted-foreground hover:text-foreground transition-colors" @click="showRegister = false">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="space-y-3">
          <input v-model="form.serial" placeholder="Serial number *" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
          <input v-model="form.model" placeholder="Weapon model (e.g. Pistol .50) *" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
          <input v-model="form.ownerName" placeholder="Owner name" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
          <input v-model="form.ownerCid" placeholder="Owner citizen ID" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
          <textarea v-model="form.notes" rows="2" placeholder="Notes" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring resize-none placeholder:text-muted-foreground" />
        </div>

        <button
          class="w-full text-sm bg-primary text-primary-foreground py-2 rounded-lg font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
          :disabled="!form.serial || !form.model || registering"
          @click="doRegister"
        >{{ registering ? 'Registering…' : 'Register Weapon' }}</button>
        <p v-if="error" class="text-xs text-red-400 text-center">{{ error }}</p>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, onMounted } from 'vue'
import { Search, Plus, X, Crosshair } from 'lucide-vue-next'
import { useWeaponStore } from '@/stores/weaponStore'
import { useAppStore } from '@/stores/appStore'

const weaponStore = useWeaponStore()
const appStore = useAppStore()

const query = ref('')
const showRegister = ref(false)
const registering = ref(false)
const error = ref('')
const form = ref({ serial: '', model: '', ownerName: '', ownerCid: '', notes: '' })

const statusBadge: Record<string, string> = {
  registered: 'bg-green-500/15 text-green-400',
  stolen: 'bg-red-500/15 text-red-400',
  seized: 'bg-yellow-500/15 text-yellow-400',
  destroyed: 'bg-secondary text-muted-foreground',
}

const statusIcon: Record<string, string> = {
  registered: 'text-green-400',
  stolen: 'text-red-400',
  seized: 'text-yellow-400',
  destroyed: 'text-muted-foreground',
}

function doSearch() {
  weaponStore.search(query.value.trim())
}

async function doRegister() {
  registering.value = true
  error.value = ''
  try {
    const result = await weaponStore.register(form.value)
    if (result.success) {
      showRegister.value = false
      form.value = { serial: '', model: '', ownerName: '', ownerCid: '', notes: '' }
    } else {
      error.value = result.error ?? 'Failed to register weapon'
    }
  } finally {
    registering.value = false
  }
}

onMounted(() => {
  // Show most recent registrations on open
  weaponStore.search('')
})
</script>
