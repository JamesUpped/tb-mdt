<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-sm font-semibold text-foreground">Department Roster</h2>
      <button
        class="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1 transition-colors"
        @click="rosterStore.load()"
      >
        <RefreshCw class="w-3.5 h-3.5" :class="rosterStore.loading ? 'animate-spin' : ''" /> Refresh
      </button>
    </div>

    <!-- Roster grouped by department -->
    <div v-for="(officers, dept) in grouped" :key="dept" class="space-y-2">
      <p class="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{{ dept }} · {{ officers.length }}</p>
      <div
        v-for="officer in officers"
        :key="officer.citizenid"
        class="flex items-center gap-4 p-3.5 rounded-xl bg-card border border-border"
      >
        <div class="w-9 h-9 rounded-full bg-secondary flex items-center justify-center shrink-0 relative">
          <UserRound class="w-4.5 h-4.5 text-muted-foreground" />
          <span
            class="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border-2 border-card"
            :class="isOnline(officer) ? statusDot[officer.status] ?? 'bg-green-500' : 'bg-gray-600'"
          />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground">{{ officer.name }}</p>
          <p class="text-xs text-muted-foreground">
            Grade {{ officer.rank }} ·
            {{ isOnline(officer) ? officer.status : 'Last seen ' + formatDate(officer.last_seen) }}
          </p>
        </div>

        <!-- Callsign (editable for managers) -->
        <div v-if="editing === officer.citizenid" class="flex items-center gap-1.5">
          <input
            v-model="callsignDraft"
            maxlength="10"
            class="w-24 text-xs bg-input border border-border rounded-lg px-2 py-1.5 text-foreground outline-none focus:ring-1 focus:ring-ring uppercase"
            @keydown.enter="saveCallsign(officer.citizenid)"
            @keydown.escape="editing = null"
          />
          <button class="text-green-400 hover:text-green-300" @click="saveCallsign(officer.citizenid)">
            <Check class="w-4 h-4" />
          </button>
          <button class="text-muted-foreground hover:text-foreground" @click="editing = null">
            <X class="w-4 h-4" />
          </button>
        </div>
        <button
          v-else
          class="text-xs font-mono px-2.5 py-1 rounded-lg bg-secondary/60 text-foreground flex items-center gap-1.5"
          :class="canManage ? 'hover:bg-secondary cursor-pointer' : 'cursor-default'"
          @click="canManage && startEdit(officer)"
        >
          {{ officer.callsign || '—' }}
          <Pencil v-if="canManage" class="w-3 h-3 text-muted-foreground" />
        </button>
      </div>
    </div>

    <div v-if="!rosterStore.loading && rosterStore.roster.length === 0" class="text-center py-12">
      <UsersRound class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
      <p class="text-sm text-muted-foreground">No officers on the roster yet</p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed, onMounted } from 'vue'
import { UserRound, UsersRound, RefreshCw, Pencil, Check, X } from 'lucide-vue-next'
import { useRosterStore } from '@/stores/rosterStore'
import { useAppStore } from '@/stores/appStore'
import type { Officer } from '@/types'

const rosterStore = useRosterStore()
const appStore = useAppStore()

const editing = ref<string | null>(null)
const callsignDraft = ref('')

const canManage = computed(() => appStore.can('roster', 'manage'))

const grouped = computed(() => {
  const map: Record<string, Officer[]> = {}
  for (const officer of rosterStore.roster) {
    const dept = officer.department || 'unknown'
    if (!map[dept]) map[dept] = []
    map[dept].push(officer)
  }
  return map
})

const statusDot: Record<string, string> = {
  available: 'bg-green-500',
  busy: 'bg-yellow-500',
  'en-route': 'bg-blue-500',
  'on-scene': 'bg-red-500',
  'off-duty': 'bg-gray-600',
}

function isOnline(officer: Officer & { last_seen?: string }) {
  const raw = (officer as { last_seen?: string }).last_seen
  if (!raw) return false
  const seen = new Date(raw).getTime()
  return !isNaN(seen) && Date.now() - seen < 5 * 60 * 1000
}

function formatDate(value?: string) {
  if (!value) return 'never'
  const d = new Date(value)
  return isNaN(d.getTime()) ? value : d.toLocaleString()
}

function startEdit(officer: Officer) {
  editing.value = officer.citizenid
  callsignDraft.value = officer.callsign || ''
}

async function saveCallsign(citizenid: string) {
  const callsign = callsignDraft.value.trim().toUpperCase()
  if (!callsign) return
  const result = await rosterStore.setCallsign(citizenid, callsign)
  if (result.success) editing.value = null
}

onMounted(() => {
  rosterStore.load()
})
</script>
