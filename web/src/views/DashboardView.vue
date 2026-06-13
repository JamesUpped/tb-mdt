<template>
  <div class="space-y-6">
    <!-- Stat cards -->
    <div class="grid grid-cols-4 gap-4">
      <StatCard label="Active Calls" :value="dispatchStore.calls.filter(c => c.status !== 'closed').length" icon="Radio" color="blue" />
      <StatCard label="Officers Online" :value="officerStore.officers.length" icon="Users" color="green" />
      <StatCard label="Open Incidents" :value="incidentStore.incidents.filter(i => i.status === 'open').length" icon="FileText" color="amber" />
      <StatCard label="Active Warrants" :value="warrantStore.warrants.filter(w => w.status === 'active').length" icon="Gavel" color="red" />
    </div>

    <!-- Announcements -->
    <div class="rounded-xl bg-card border border-border p-4">
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-sm font-semibold text-foreground flex items-center gap-2">
          <Megaphone class="w-4 h-4 text-primary" /> Department Announcements
        </h2>
        <button
          v-if="appStore.can('announcements', 'create')"
          class="text-xs bg-secondary text-foreground px-3 py-1.5 rounded-lg hover:bg-secondary/70 transition-colors flex items-center gap-1"
          @click="showCreate = true"
        >
          <Plus class="w-3.5 h-3.5" /> New
        </button>
      </div>
      <div v-if="announcementStore.announcements.length === 0" class="text-sm text-muted-foreground py-3 text-center">No announcements</div>
      <div v-else class="space-y-2 max-h-[220px] overflow-auto">
        <div
          v-for="a in announcementStore.announcements"
          :key="a.id"
          class="flex items-start gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50"
          :class="a.priority === 'urgent' ? 'border-red-500/40' : a.priority === 'important' ? 'border-yellow-500/40' : ''"
        >
          <div class="w-2 h-2 mt-1.5 rounded-full shrink-0" :class="announcementDot(a.priority)" />
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-foreground">{{ a.title }}</p>
            <p v-if="a.body" class="text-xs text-muted-foreground whitespace-pre-wrap">{{ a.body }}</p>
            <p class="text-[10px] text-muted-foreground/70 mt-1">{{ a.created_by }} · {{ formatDate(a.created_at) }}</p>
          </div>
          <button
            v-if="appStore.can('announcements', 'remove')"
            class="text-muted-foreground hover:text-red-400 transition-colors"
            @click="announcementStore.remove(a.id)"
          >
            <Trash2 class="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </div>

    <!-- Create announcement modal -->
    <div v-if="showCreate" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60" @click.self="showCreate = false">
      <div class="w-[440px] rounded-xl bg-card border border-border shadow-2xl p-5 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="text-base font-semibold text-foreground">New Announcement</h2>
          <button class="text-muted-foreground hover:text-foreground transition-colors" @click="showCreate = false">
            <X class="w-5 h-5" />
          </button>
        </div>
        <input v-model="createForm.title" placeholder="Title *" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
        <textarea v-model="createForm.body" rows="3" placeholder="Message" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring resize-none placeholder:text-muted-foreground" />
        <div class="flex gap-1.5">
          <button
            v-for="p in (['normal', 'important', 'urgent'] as const)"
            :key="p"
            class="text-xs px-3 py-1.5 rounded-lg capitalize transition-colors border"
            :class="createForm.priority === p
              ? (p === 'urgent' ? 'bg-red-500/15 text-red-400 border-red-500/40' : p === 'important' ? 'bg-yellow-500/15 text-yellow-400 border-yellow-500/40' : 'bg-primary/10 text-primary border-primary/40')
              : 'text-muted-foreground border-border hover:text-foreground'"
            @click="createForm.priority = p"
          >{{ p }}</button>
        </div>
        <button
          class="w-full text-sm bg-primary text-primary-foreground py-2 rounded-lg font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
          :disabled="!createForm.title || creating"
          @click="createAnnouncement"
        >{{ creating ? 'Posting…' : 'Post Announcement' }}</button>
      </div>
    </div>

    <div class="grid grid-cols-2 gap-6">
      <!-- Recent calls -->
      <div class="rounded-xl bg-card border border-border p-4">
        <h2 class="text-sm font-semibold text-foreground mb-3">Recent Dispatch Calls</h2>
        <div v-if="recentCalls.length === 0" class="text-sm text-muted-foreground py-4 text-center">No active calls</div>
        <div v-else class="space-y-2 max-h-[300px] overflow-auto">
          <div
            v-for="call in recentCalls"
            :key="call.id"
            class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50"
          >
            <div class="w-2 h-2 rounded-full shrink-0" :class="priorityColor(call.priority)" />
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-foreground truncate">{{ call.description || call.caller }}</p>
              <p class="text-xs text-muted-foreground">{{ call.location }}</p>
            </div>
            <span class="text-xs px-2 py-0.5 rounded-full border border-border text-muted-foreground capitalize">{{ call.status }}</span>
          </div>
        </div>
      </div>

      <!-- Recent incidents -->
      <div class="rounded-xl bg-card border border-border p-4">
        <h2 class="text-sm font-semibold text-foreground mb-3">Recent Incidents</h2>
        <div v-if="recentIncidents.length === 0" class="text-sm text-muted-foreground py-4 text-center">No recent incidents</div>
        <div v-else class="space-y-2 max-h-[300px] overflow-auto">
          <div
            v-for="incident in recentIncidents"
            :key="incident.id"
            class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-foreground truncate">{{ incident.title }}</p>
              <p class="text-xs text-muted-foreground">Case #{{ incident.caseNumber }}</p>
            </div>
            <span
              class="text-xs px-2 py-0.5 rounded-full border capitalize"
              :class="incident.status === 'open' ? 'border-amber-500/30 text-amber-400' : 'border-green-500/30 text-green-400'"
            >{{ incident.status }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Online officers -->
    <div class="rounded-xl bg-card border border-border p-4">
      <h2 class="text-sm font-semibold text-foreground mb-3">Officers On Duty</h2>
      <div v-if="officerStore.officers.length === 0" class="text-sm text-muted-foreground py-4 text-center">No officers online</div>
      <div v-else class="grid grid-cols-4 gap-2">
        <div
          v-for="officer in officerStore.officers"
          :key="officer.id"
          class="flex items-center gap-2 p-2 rounded-lg bg-secondary/40 border border-border/50"
        >
          <div class="w-2 h-2 rounded-full shrink-0" :class="officerStatusColor(officer.status)" />
          <div class="min-w-0">
            <p class="text-xs font-medium text-foreground truncate">{{ officer.callsign }} — {{ officer.name }}</p>
            <p class="text-[10px] text-muted-foreground capitalize">{{ officer.status }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, onMounted } from 'vue'
import { Megaphone, Plus, Trash2, X } from 'lucide-vue-next'
import { useDispatchStore } from '@/stores/dispatchStore'
import { useOfficerStore } from '@/stores/officerStore'
import { useIncidentStore } from '@/stores/incidentStore'
import { useWarrantStore } from '@/stores/warrantStore'
import { useAnnouncementStore } from '@/stores/announcementStore'
import { useAppStore } from '@/stores/appStore'
import StatCard from '@/components/ui/StatCard.vue'

const dispatchStore = useDispatchStore()
const officerStore = useOfficerStore()
const incidentStore = useIncidentStore()
const warrantStore = useWarrantStore()
const announcementStore = useAnnouncementStore()
const appStore = useAppStore()

const showCreate = ref(false)
const creating = ref(false)
const createForm = ref<{ title: string; body: string; priority: 'normal' | 'important' | 'urgent' }>({
  title: '',
  body: '',
  priority: 'normal',
})

const recentCalls = computed(() => dispatchStore.calls.slice(0, 8))
const recentIncidents = computed(() => incidentStore.incidents.slice(0, 8))

function announcementDot(p: string) {
  const map: Record<string, string> = {
    normal: 'bg-blue-500',
    important: 'bg-yellow-500',
    urgent: 'bg-red-500',
  }
  return map[p] ?? 'bg-gray-500'
}

function formatDate(value: string) {
  if (!value) return ''
  const d = new Date(value)
  return isNaN(d.getTime()) ? value : d.toLocaleString()
}

async function createAnnouncement() {
  if (!createForm.value.title || creating.value) return
  creating.value = true
  try {
    const result = await announcementStore.create(createForm.value)
    if (result.success) {
      showCreate.value = false
      createForm.value = { title: '', body: '', priority: 'normal' }
    }
  } finally {
    creating.value = false
  }
}

onMounted(() => {
  announcementStore.load()
})

function priorityColor(p: string) {
  const map: Record<string, string> = {
    low: 'bg-green-500',
    medium: 'bg-yellow-500',
    high: 'bg-orange-500',
    critical: 'bg-red-500',
  }
  return map[p] ?? 'bg-gray-500'
}

function officerStatusColor(s: string) {
  const map: Record<string, string> = {
    available: 'bg-green-500',
    busy: 'bg-yellow-500',
    'en-route': 'bg-blue-500',
    'on-scene': 'bg-red-500',
    'off-duty': 'bg-gray-500',
  }
  return map[s] ?? 'bg-gray-500'
}
</script>
