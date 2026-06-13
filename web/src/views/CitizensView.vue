<template>
  <div class="space-y-4">
    <!-- Search bar -->
    <div class="flex items-center gap-3">
      <div class="relative flex-1">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input
          v-model="query"
          placeholder="Search by name, citizen ID, or phone..."
          class="w-full text-sm bg-input border border-border rounded-lg pl-10 pr-4 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground"
          @keydown.enter="doSearch"
        />
      </div>
      <button
        class="text-sm bg-primary text-primary-foreground px-4 py-2 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        :disabled="citizenStore.loading"
        @click="doSearch"
      >Search</button>
    </div>

    <!-- Results list -->
    <div v-if="citizenStore.results.length > 0 && !citizenStore.activeProfile" class="space-y-2">
      <div
        v-for="citizen in citizenStore.results"
        :key="citizen.citizenid"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border hover:border-primary/30 cursor-pointer transition-colors"
        @click="citizenStore.loadProfile(citizen.citizenid)"
      >
        <div class="w-10 h-10 rounded-full bg-secondary flex items-center justify-center">
          <User class="w-5 h-5 text-muted-foreground" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground">{{ citizen.name ?? `${citizen.firstname ?? ''} ${citizen.lastname ?? ''}` }}</p>
          <p class="text-xs text-muted-foreground">ID: {{ citizen.citizenid }} · DOB: {{ citizen.dob }}</p>
        </div>
        <ChevronRight class="w-4 h-4 text-muted-foreground" />
      </div>
    </div>

    <!-- Profile view -->
    <div v-if="citizenStore.activeProfile" class="space-y-4">
      <div class="flex items-center justify-between">
        <button class="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1 transition-colors" @click="citizenStore.clearProfile()">
          <ArrowLeft class="w-3 h-3" /> Back to results
        </button>
        <button
          v-if="appStore.can('charges', 'process')"
          class="text-xs bg-red-500/15 text-red-400 border border-red-500/30 px-3 py-1.5 rounded-lg font-medium hover:bg-red-500/25 transition-colors flex items-center gap-1.5"
          @click="showCalculator = true"
        >
          <Gavel class="w-3.5 h-3.5" /> Process Charges
        </button>
      </div>

      <div class="grid grid-cols-3 gap-4">
        <!-- Personal info card -->
        <div class="col-span-1 rounded-xl bg-card border border-border p-4 space-y-3">
          <!-- Mugshot -->
          <div class="w-24 h-24 mx-auto rounded-xl bg-secondary flex items-center justify-center overflow-hidden">
            <img v-if="profile.image" :src="profile.image" class="w-full h-full object-cover" alt="Mugshot" />
            <User v-else class="w-10 h-10 text-muted-foreground" />
          </div>
          <div class="text-center">
            <p class="text-base font-semibold text-foreground">{{ displayName }}</p>
            <p class="text-xs text-muted-foreground">{{ profile.citizenid }}</p>
          </div>

          <!-- Flags -->
          <div v-if="(profile.flags ?? []).length > 0" class="flex flex-wrap justify-center gap-1">
            <span
              v-for="flag in profile.flags"
              :key="flag"
              class="text-[10px] px-2 py-0.5 rounded-full font-medium uppercase tracking-wide"
              :class="flagStyles[flag] ?? 'bg-secondary text-muted-foreground'"
            >{{ flagLabels[flag] ?? flag }}</span>
          </div>

          <div class="space-y-2 text-xs">
            <InfoRow label="Date of Birth" :value="profile.dob" />
            <InfoRow label="Phone" :value="profile.phone" />
            <InfoRow label="Gender" :value="profile.gender" />
            <InfoRow label="Nationality" :value="profile.nationality" />
          </div>

          <!-- Rap sheet summary -->
          <div class="grid grid-cols-3 gap-1.5 pt-1">
            <div class="rounded-lg bg-secondary/40 py-1.5 text-center">
              <p class="text-sm font-semibold" :class="(profile.convictionCount ?? 0) > 0 ? 'text-red-400' : 'text-foreground'">{{ profile.convictionCount ?? 0 }}</p>
              <p class="text-[9px] text-muted-foreground">Convictions</p>
            </div>
            <div class="rounded-lg bg-secondary/40 py-1.5 text-center">
              <p class="text-sm font-semibold" :class="(profile.unpaidFines ?? 0) > 0 ? 'text-yellow-400' : 'text-foreground'">${{ (profile.unpaidFines ?? 0).toLocaleString() }}</p>
              <p class="text-[9px] text-muted-foreground">Unpaid fines</p>
            </div>
            <div class="rounded-lg bg-secondary/40 py-1.5 text-center">
              <p class="text-sm font-semibold text-foreground">{{ profile.licensePoints ?? 0 }}</p>
              <p class="text-[9px] text-muted-foreground">Points (30d)</p>
            </div>
          </div>

          <button
            v-if="appStore.can('profiles', 'edit')"
            class="w-full text-xs bg-secondary text-foreground py-1.5 rounded-lg hover:bg-secondary/70 transition-colors flex items-center justify-center gap-1.5"
            @click="openEditor"
          >
            <Pencil class="w-3 h-3" /> Edit profile
          </button>
        </div>

        <!-- Tabs area -->
        <div class="col-span-2 rounded-xl bg-card border border-border p-4">
          <div class="flex gap-2 border-b border-border pb-2 mb-3">
            <button
              v-for="tab in tabs"
              :key="tab"
              class="text-xs px-3 py-1.5 rounded-lg transition-colors capitalize"
              :class="activeTab === tab ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
              @click="selectTab(tab)"
            >{{ tabLabels[tab] }}</button>
          </div>

          <!-- Vehicles tab -->
          <div v-if="activeTab === 'vehicles'" class="space-y-2 max-h-[350px] overflow-auto">
            <div v-if="!profile.vehicles?.length" class="text-sm text-muted-foreground text-center py-4">No registered vehicles</div>
            <div v-for="v in profile.vehicles" :key="v.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
              <Car class="w-4 h-4 text-muted-foreground shrink-0" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-foreground">{{ v.plate }}</p>
                <p class="text-xs text-muted-foreground">{{ v.model }}</p>
              </div>
            </div>
          </div>

          <!-- Incidents tab -->
          <div v-if="activeTab === 'incidents'" class="space-y-2 max-h-[350px] overflow-auto">
            <div v-if="!profile.incidents?.length" class="text-sm text-muted-foreground text-center py-4">No linked incidents</div>
            <div v-for="i in profile.incidents" :key="i.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
              <FileText class="w-4 h-4 text-muted-foreground shrink-0" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-foreground truncate">{{ i.title }}</p>
                <p class="text-xs text-muted-foreground">Case #{{ i.caseNumber }} · {{ i.status }}</p>
              </div>
            </div>
          </div>

          <!-- Warrants tab -->
          <div v-if="activeTab === 'warrants'" class="space-y-2 max-h-[350px] overflow-auto">
            <div v-if="!profile.warrants?.length" class="text-sm text-muted-foreground text-center py-4">No warrants</div>
            <div v-for="w in profile.warrants" :key="w.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
              <Gavel class="w-4 h-4 shrink-0" :class="w.status === 'active' ? 'text-red-400' : 'text-muted-foreground'" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-foreground truncate">{{ w.charges }}</p>
                <p class="text-xs text-muted-foreground">{{ w.status }} · Issued {{ w.issuedAt }}</p>
              </div>
            </div>
          </div>

          <!-- Rap sheet tab -->
          <div v-if="activeTab === 'rapsheet'" class="space-y-3 max-h-[350px] overflow-auto">
            <div v-if="rapSheetLoading" class="text-sm text-muted-foreground text-center py-4">Loading rap sheet…</div>
            <template v-else-if="citizenStore.rapSheet">
              <div v-if="!citizenStore.rapSheet.charges.length && !citizenStore.rapSheet.fines.length" class="text-sm text-muted-foreground text-center py-4">
                Clean record — no convictions on file
              </div>

              <div v-if="citizenStore.rapSheet.charges.length" class="space-y-2">
                <p class="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Convictions</p>
                <div v-for="c in citizenStore.rapSheet.charges" :key="c.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
                  <Scale class="w-4 h-4 shrink-0" :class="c.category === 'felony' ? 'text-red-400' : c.category === 'misdemeanor' ? 'text-yellow-400' : 'text-blue-400'" />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-foreground truncate">{{ c.charge_id }} · {{ c.charge_title }}</p>
                    <p class="text-xs text-muted-foreground">
                      ${{ c.fine.toLocaleString() }}<template v-if="c.jail > 0"> · {{ c.jail }} min</template>
                      · {{ formatDate(c.created_at) }} · {{ c.officer }}
                    </p>
                  </div>
                  <span class="text-[10px] px-2 py-0.5 rounded-full capitalize" :class="categoryBadge[c.category] ?? 'bg-secondary text-muted-foreground'">{{ c.category }}</span>
                </div>
              </div>

              <div v-if="citizenStore.rapSheet.fines.length" class="space-y-2">
                <p class="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Fines</p>
                <div v-for="f in citizenStore.rapSheet.fines" :key="f.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
                  <Banknote class="w-4 h-4 shrink-0" :class="f.status === 'unpaid' ? 'text-yellow-400' : 'text-green-400'" />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-foreground">${{ f.amount.toLocaleString() }}</p>
                    <p class="text-xs text-muted-foreground truncate">{{ f.charges }} · {{ formatDate(f.created_at) }}</p>
                  </div>
                  <span class="text-[10px] px-2 py-0.5 rounded-full capitalize" :class="f.status === 'unpaid' ? 'bg-yellow-500/15 text-yellow-400' : 'bg-green-500/15 text-green-400'">{{ f.status }}</span>
                </div>
              </div>
            </template>
          </div>

          <!-- Licenses tab -->
          <div v-if="activeTab === 'licenses'" class="space-y-2 max-h-[350px] overflow-auto">
            <div v-if="!Object.keys(profile.licenses ?? {}).length" class="text-sm text-muted-foreground text-center py-4">No licenses on record</div>
            <div v-for="(valid, name) in profile.licenses" :key="name" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
              <div class="w-2 h-2 rounded-full" :class="valid ? 'bg-green-500' : 'bg-red-500'" />
              <p class="text-sm text-foreground capitalize">{{ name }}</p>
              <span class="text-xs text-muted-foreground">{{ valid ? 'Valid' : 'Revoked' }}</span>
              <button
                v-if="appStore.can('licenses', 'manage')"
                class="ml-auto text-[10px] px-2.5 py-1 rounded-lg font-medium transition-colors"
                :class="valid
                  ? 'bg-red-500/15 text-red-400 border border-red-500/30 hover:bg-red-500/25'
                  : 'bg-green-500/15 text-green-400 border border-green-500/30 hover:bg-green-500/25'"
                @click="toggleLicense(String(name), !valid)"
              >{{ valid ? 'Revoke' : 'Grant' }}</button>
            </div>
          </div>

          <!-- Notes tab -->
          <div v-if="activeTab === 'notes'" class="space-y-2">
            <p v-if="!profile.notes" class="text-sm text-muted-foreground text-center py-4">No officer notes — use Edit profile to add some</p>
            <p v-else class="text-sm text-foreground whitespace-pre-wrap p-3 rounded-lg bg-secondary/40 border border-border/50 max-h-[330px] overflow-auto">{{ profile.notes }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty state -->
    <div v-if="citizenStore.results.length === 0 && !citizenStore.activeProfile && !citizenStore.loading" class="text-center py-12">
      <Users class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
      <p class="text-sm text-muted-foreground">Search for a citizen to view their profile</p>
    </div>

    <!-- Charge calculator modal -->
    <ChargeCalculator
      v-if="showCalculator && citizenStore.activeProfile"
      :citizenid="profile.citizenid"
      :citizen-name="displayName"
      @close="showCalculator = false"
      @processed="onProcessed"
    />

    <!-- Profile editor modal -->
    <div v-if="showEditor" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60" @click.self="showEditor = false">
      <div class="w-[480px] rounded-xl bg-card border border-border shadow-2xl p-5 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="text-base font-semibold text-foreground">Edit Profile</h2>
          <button class="text-muted-foreground hover:text-foreground transition-colors" @click="showEditor = false">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="space-y-3">
          <div>
            <label class="text-xs text-muted-foreground">Mugshot URL</label>
            <input
              v-model="editorForm.image"
              placeholder="https://… (FiveManage / Discord CDN / imgur)"
              class="mt-1 w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground"
            />
          </div>
          <div>
            <label class="text-xs text-muted-foreground">Officer notes</label>
            <textarea
              v-model="editorForm.notes"
              rows="4"
              class="mt-1 w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring resize-none"
            />
          </div>
          <div>
            <label class="text-xs text-muted-foreground">Flags</label>
            <div class="mt-1.5 flex flex-wrap gap-1.5">
              <button
                v-for="(label, flag) in flagLabels"
                :key="flag"
                class="text-[10px] px-2.5 py-1 rounded-full font-medium uppercase tracking-wide border transition-colors"
                :class="editorForm.flags.includes(flag)
                  ? (flagStyles[flag] ?? 'bg-secondary text-foreground') + ' border-transparent'
                  : 'bg-transparent text-muted-foreground border-border hover:text-foreground'"
                @click="toggleEditorFlag(flag)"
              >{{ label }}</button>
            </div>
          </div>
        </div>

        <button
          class="w-full text-sm bg-primary text-primary-foreground py-2 rounded-lg font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
          :disabled="savingExtras"
          @click="saveEditor"
        >{{ savingExtras ? 'Saving…' : 'Save' }}</button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed } from 'vue'
import {
  Search, User, ChevronRight, ArrowLeft, Car, FileText, Gavel, Users,
  Scale, Banknote, Pencil, X,
} from 'lucide-vue-next'
import { useCitizenStore } from '@/stores/citizenStore'
import { useAppStore } from '@/stores/appStore'
import InfoRow from '@/components/ui/InfoRow.vue'
import ChargeCalculator from '@/components/ChargeCalculator.vue'

type ProfileTab = 'vehicles' | 'incidents' | 'warrants' | 'rapsheet' | 'licenses' | 'notes'

const citizenStore = useCitizenStore()
const appStore = useAppStore()
const query = ref('')
const activeTab = ref<ProfileTab>('vehicles')
const tabs: ProfileTab[] = ['vehicles', 'incidents', 'warrants', 'rapsheet', 'licenses', 'notes']
const tabLabels: Record<ProfileTab, string> = {
  vehicles: 'Vehicles',
  incidents: 'Incidents',
  warrants: 'Warrants',
  rapsheet: 'Rap Sheet',
  licenses: 'Licenses',
  notes: 'Notes',
}

const showCalculator = ref(false)
const showEditor = ref(false)
const rapSheetLoading = ref(false)
const savingExtras = ref(false)
const editorForm = ref({ image: '', notes: '', flags: [] as string[] })

const flagLabels: Record<string, string> = {
  violent: 'Violent',
  armed: 'Armed',
  gang: 'Gang Affiliated',
  flight_risk: 'Flight Risk',
  informant: 'Informant',
  mental_health: 'Mental Health',
}

const flagStyles: Record<string, string> = {
  violent: 'bg-red-500/15 text-red-400',
  armed: 'bg-orange-500/15 text-orange-400',
  gang: 'bg-purple-500/15 text-purple-400',
  flight_risk: 'bg-yellow-500/15 text-yellow-400',
  informant: 'bg-blue-500/15 text-blue-400',
  mental_health: 'bg-teal-500/15 text-teal-400',
}

const categoryBadge: Record<string, string> = {
  traffic: 'bg-blue-500/15 text-blue-400',
  misdemeanor: 'bg-yellow-500/15 text-yellow-400',
  felony: 'bg-red-500/15 text-red-400',
}

const profile = computed(() => citizenStore.activeProfile!)
const displayName = computed(() =>
  profile.value.name ?? `${profile.value.firstname ?? ''} ${profile.value.lastname ?? ''}`.trim()
)

function doSearch() {
  if (query.value.trim()) {
    citizenStore.search(query.value.trim())
  }
}

async function selectTab(tab: ProfileTab) {
  activeTab.value = tab
  if (tab === 'rapsheet' && !citizenStore.rapSheet) {
    rapSheetLoading.value = true
    try {
      await citizenStore.loadRapSheet(profile.value.citizenid)
    } finally {
      rapSheetLoading.value = false
    }
  }
}

async function toggleLicense(license: string, status: boolean) {
  await citizenStore.setLicense(profile.value.citizenid, license, status)
}

function openEditor() {
  editorForm.value = {
    image: profile.value.image ?? '',
    notes: profile.value.notes ?? '',
    flags: [...(profile.value.flags ?? [])],
  }
  showEditor.value = true
}

function toggleEditorFlag(flag: string) {
  const idx = editorForm.value.flags.indexOf(flag)
  if (idx >= 0) editorForm.value.flags.splice(idx, 1)
  else editorForm.value.flags.push(flag)
}

async function saveEditor() {
  savingExtras.value = true
  try {
    const result = await citizenStore.saveExtras(profile.value.citizenid, editorForm.value)
    if (result.success) showEditor.value = false
  } finally {
    savingExtras.value = false
  }
}

async function onProcessed() {
  // Refresh summary counters after charging
  await citizenStore.loadProfile(profile.value.citizenid)
  activeTab.value = 'rapsheet'
  await selectTab('rapsheet')
}

function formatDate(value: string) {
  if (!value) return ''
  const d = new Date(value)
  return isNaN(d.getTime()) ? value : d.toLocaleDateString()
}
</script>
