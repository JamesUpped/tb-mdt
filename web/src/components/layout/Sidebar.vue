<template>
  <aside class="w-16 flex flex-col items-center py-4 bg-sidebar border-r border-sidebar-border gap-1">
    <!-- Logo -->
    <div class="w-10 h-10 rounded-lg bg-primary/20 flex items-center justify-center mb-4">
      <Shield class="w-5 h-5 text-primary" />
    </div>

    <!-- Nav items -->
    <button
      v-for="item in navItems"
      :key="item.view"
      :title="item.label"
      class="relative w-10 h-10 rounded-lg flex items-center justify-center transition-colors"
      :class="appStore.currentView === item.view
        ? 'bg-sidebar-accent text-sidebar-primary'
        : 'text-muted-foreground hover:text-sidebar-foreground hover:bg-sidebar-accent/50'"
      @click="appStore.setView(item.view)"
    >
      <component :is="item.icon" class="w-5 h-5" />
      <!-- Badge -->
      <span
        v-if="item.badge > 0"
        class="absolute -top-1 -right-1 min-w-[18px] h-[18px] rounded-full bg-destructive-foreground text-[10px] font-bold text-white flex items-center justify-center px-1"
      >
        {{ item.badge > 99 ? '99+' : item.badge }}
      </span>
    </button>

    <div class="flex-1" />

    <!-- Status indicator -->
    <button
      title="Update Status"
      class="w-10 h-10 rounded-lg flex items-center justify-center text-muted-foreground hover:text-sidebar-foreground hover:bg-sidebar-accent/50 transition-colors"
      @click="cycleStatus"
    >
      <Radio class="w-5 h-5" :class="statusColor" />
    </button>
  </aside>
</template>

<script lang="ts" setup>
import { computed } from 'vue'
import {
  Shield,
  LayoutDashboard,
  Radio as RadioIcon,
  Users,
  Car,
  FileText,
  Gavel,
  AlertTriangle,
  Camera,
  Radio,
  Crosshair,
  UsersRound,
} from 'lucide-vue-next'
import { useAppStore } from '@/stores/appStore'
import { useDispatchStore } from '@/stores/dispatchStore'
import { useWarrantStore } from '@/stores/warrantStore'
import { useBoloStore } from '@/stores/boloStore'
import { useOfficerStore } from '@/stores/officerStore'
import { fetchNui } from '@/composables/fetchNui'
import type { MDTView } from '@/types'

const appStore = useAppStore()
const dispatchStore = useDispatchStore()
const warrantStore = useWarrantStore()
const boloStore = useBoloStore()
const officerStore = useOfficerStore()

interface NavItem {
  view: MDTView
  label: string
  icon: typeof LayoutDashboard
  badge: number
}

const navItems = computed<NavItem[]>(() => [
  { view: 'dashboard', label: 'Dashboard', icon: LayoutDashboard, badge: 0 },
  { view: 'dispatch', label: 'Dispatch', icon: RadioIcon, badge: dispatchStore.calls.filter(c => c.status === 'pending').length },
  { view: 'citizens', label: 'Citizens', icon: Users, badge: 0 },
  { view: 'vehicles', label: 'Vehicles', icon: Car, badge: 0 },
  { view: 'incidents', label: 'Incidents', icon: FileText, badge: 0 },
  { view: 'warrants', label: 'Warrants', icon: Gavel, badge: warrantStore.warrants.filter(w => w.status === 'active').length },
  { view: 'bolos', label: 'BOLOs', icon: AlertTriangle, badge: boloStore.bolos.filter(b => b.status === 'active').length },
  { view: 'evidence', label: 'Evidence', icon: Camera, badge: 0 },
  { view: 'weapons', label: 'Weapons Registry', icon: Crosshair, badge: 0 },
  { view: 'roster', label: 'Roster', icon: UsersRound, badge: 0 },
])

const statuses = ['available', 'busy', 'en-route', 'on-scene'] as const
const statusColors: Record<string, string> = {
  available: 'text-green-500',
  busy: 'text-yellow-500',
  'en-route': 'text-blue-500',
  'on-scene': 'text-red-500',
}

const statusColor = computed(() => {
  const current = officerStore.officers.find(o => o.callsign === appStore.player?.callsign)
  return statusColors[current?.status ?? 'available'] ?? 'text-muted-foreground'
})

function cycleStatus() {
  const current = officerStore.officers.find(o => o.callsign === appStore.player?.callsign)
  const idx = statuses.indexOf((current?.status ?? 'available') as typeof statuses[number])
  const next = statuses[(idx + 1) % statuses.length]
  officerStore.updateStatus(next)
}
</script>
