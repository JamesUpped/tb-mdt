/* ── tb-mdt shared type definitions ── */

export interface Officer {
  id: number
  citizenid: string
  name: string
  callsign: string
  department: string
  rank: string
  status: 'available' | 'busy' | 'en-route' | 'on-scene' | 'off-duty'
  lastSeen?: string
}

export type PermissionValue = boolean | number | Record<string, boolean | number>

export interface PlayerInfo {
  name: string
  callsign: string
  department: DepartmentConfig
  rank: string
  gradeLevel: number
  permissions: Record<string, PermissionValue>
}

export interface DepartmentConfig {
  name: string
  label: string
  color: string
  logo?: string
}

export interface DispatchCall {
  id: number
  caller: string
  location: string
  description: string
  priority: 'low' | 'medium' | 'high' | 'critical'
  status: 'pending' | 'assigned' | 'en-route' | 'on-scene' | 'closed'
  assignedOfficers: string[]
  timestamp: string
  caseNumber?: string
}

export interface CitizenProfile {
  citizenid: string
  name?: string
  firstname: string
  lastname: string
  dob: string
  phone: string
  gender: string
  nationality: string
  photo?: string
  vehicles: VehicleRecord[]
  incidents: IncidentRecord[]
  warrants: WarrantRecord[]
  licenses: Record<string, boolean>
  // Profile extras (mdt_profiles)
  image?: string
  notes?: string
  flags?: string[]
  // Rap sheet summary
  convictionCount?: number
  unpaidFines?: number
  licensePoints?: number
}

export interface VehicleRecord {
  id: number
  plate: string
  model: string
  owner: string
  ownerCitizenid: string
  color?: string
  bolos: BOLORecord[]
  incidents: IncidentRecord[]
  stolen?: boolean
  flagNotes?: string
}

export interface IncidentRecord {
  id: number
  caseNumber: string
  title: string
  description: string
  location: string
  status: 'open' | 'closed' | 'archived'
  officers: string[]
  suspects: string[]
  charges: Charge[]
  createdBy: string
  createdAt: string
  closedAt?: string
}

export interface Charge {
  id: number
  title: string
  category: 'traffic' | 'misdemeanor' | 'felony'
  fine: number
  jail: number
  points: number
}

/* Penal code definition (config) — officers slide between min/max */
export interface PenalCharge {
  id: string
  title: string
  fineMin: number
  fineMax: number
  jailMin: number
  jailMax: number
  points: number
}

export type PenalCode = Record<string, PenalCharge[]>

/* A charge being prepared in the calculator */
export interface SelectedCharge {
  id: string
  title: string
  category: string
  fine: number
  jail: number
  points: number
  fineMin: number
  fineMax: number
  jailMin: number
  jailMax: number
}

/* Conviction row (mdt_charges) */
export interface RapSheetCharge {
  id: number
  citizenid: string
  citizen_name: string
  charge_id: string
  charge_title: string
  category: string
  fine: number
  jail: number
  points: number
  incident_id?: number
  officer: string
  created_at: string
}

/* Fine row (mdt_fines) */
export interface FineRecord {
  id: number
  citizenid: string
  citizen_name: string
  amount: number
  charges: string
  status: 'paid' | 'unpaid'
  officer: string
  created_at: string
  paid_at?: string
}

export interface RapSheet {
  charges: RapSheetCharge[]
  fines: FineRecord[]
  points: number
}

/* Weapon registry row (mdt_weapons) */
export interface WeaponRecord {
  id: number
  serial: string
  model: string
  owner_cid: string
  owner_name: string
  status: 'registered' | 'stolen' | 'seized' | 'destroyed'
  notes: string
  registered_by: string
  created_at: string
  updated_at: string
}

/* Announcement row (mdt_announcements) */
export interface AnnouncementRecord {
  id: number
  title: string
  body: string
  priority: 'normal' | 'important' | 'urgent'
  created_by: string
  created_at: string
}

/* Panic alert payload */
export interface PanicAlert {
  officer: string
  callsign: string
  coords: { x: number; y: number; z: number }
}

export interface WarrantRecord {
  id: number
  suspectName: string
  suspectCitizenid: string
  charges: string
  description: string
  status: 'active' | 'executed' | 'expired'
  issuedBy: string
  issuedAt: string
  executedBy?: string
  executedAt?: string
}

export interface BOLORecord {
  id: number
  type: 'person' | 'vehicle'
  description: string
  plate?: string
  suspectName?: string
  reason: string
  status: 'active' | 'inactive'
  createdBy: string
  createdAt: string
}

export interface EvidenceRecord {
  id: number
  incidentId: number
  type: string
  description: string
  metadata?: string
  addedBy: string
  addedAt: string
}

export interface DashboardStats {
  activeCalls: number
  officersOnline: number
  openIncidents: number
  activeWarrants: number
  activeBolos: number
  recentCalls: DispatchCall[]
  recentIncidents: IncidentRecord[]
}

export interface UIConfig {
  maxSearchResults: number
  dateFormat: string
  itemsPerPage: number
}

export interface MDTConfig {
  ui: UIConfig
  priority: Record<string, { color: string; label: string }>
  offenses: Record<string, { label: string; color: string }>
  evidence: Record<string, { label: string; icon: string }>
  penalCode: PenalCode
}

export type MDTView = 'dashboard' | 'dispatch' | 'citizens' | 'vehicles' | 'incidents' | 'warrants' | 'bolos' | 'evidence' | 'weapons' | 'roster'
