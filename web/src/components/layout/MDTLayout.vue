<template>
  <div class="flex h-full rounded-xl overflow-hidden border border-border bg-background/95 shadow-2xl shadow-black/50">
    <!-- Sidebar -->
    <Sidebar />

    <!-- Main content area -->
    <div class="flex flex-col flex-1 min-w-0">
      <Header />
      <main class="flex-1 overflow-auto p-6">
        <Transition name="fade" mode="out-in">
          <component :is="activeView" :key="appStore.currentView" />
        </Transition>
      </main>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue'
import { useAppStore } from '@/stores/appStore'
import Sidebar from './Sidebar.vue'
import Header from './Header.vue'
import DashboardView from '@/views/DashboardView.vue'
import DispatchView from '@/views/DispatchView.vue'
import CitizensView from '@/views/CitizensView.vue'
import VehiclesView from '@/views/VehiclesView.vue'
import IncidentsView from '@/views/IncidentsView.vue'
import WarrantsView from '@/views/WarrantsView.vue'
import BOLOsView from '@/views/BOLOsView.vue'
import EvidenceView from '@/views/EvidenceView.vue'
import WeaponsView from '@/views/WeaponsView.vue'
import RosterView from '@/views/RosterView.vue'

const appStore = useAppStore()

const viewMap: Record<string, ReturnType<typeof defineComponent>> = {
  dashboard: DashboardView,
  dispatch: DispatchView,
  citizens: CitizensView,
  vehicles: VehiclesView,
  incidents: IncidentsView,
  warrants: WarrantsView,
  bolos: BOLOsView,
  evidence: EvidenceView,
  weapons: WeaponsView,
  roster: RosterView,
}

const activeView = computed(() => viewMap[appStore.currentView] ?? DashboardView)
</script>
