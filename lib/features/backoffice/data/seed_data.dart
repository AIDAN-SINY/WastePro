import '../models.dart';

/// Default backoffice data (same entities as `backoffice-mobile.html`).
const List<ClientModel> seedClients = [
  ClientModel(
    id: 'cl1',
    name: 'Jean Dooh',
    phone: '+237 677 12 34 56',
    zone: 'Bonanjo',
    plan: 'Standard',
    status: 'Active',
  ),
  ClientModel(
    id: 'cl2',
    name: 'Marie Ekwalla',
    phone: '+237 690 45 12 78',
    zone: 'Akwa',
    plan: 'Premium',
    status: 'Active',
  ),
  ClientModel(
    id: 'cl3',
    name: 'Samuel Njoya',
    phone: '+237 655 88 21 09',
    zone: 'Bonapriso',
    plan: 'Essential',
    status: 'Suspended',
  ),
  ClientModel(
    id: 'cl4',
    name: 'Aïcha Bello',
    phone: '+237 699 33 67 41',
    zone: 'Deido',
    plan: 'Standard',
    status: 'Active',
  ),
  ClientModel(
    id: 'cl5',
    name: 'Patrice Fotso',
    phone: '+237 674 20 15 63',
    zone: 'Bali',
    plan: 'Premium',
    status: 'Active',
  ),
  ClientModel(
    id: 'cl6',
    name: 'Sarah Mbida',
    phone: '+237 691 77 04 22',
    zone: 'Bonanjo',
    plan: 'Essential',
    status: 'Active',
  ),
  ClientModel(
    id: 'cl7',
    name: 'Éric Tchoua',
    phone: '+237 656 40 88 15',
    zone: 'Ndogbong',
    plan: 'Standard',
    status: 'Suspended',
  ),
];

const List<CollecteurModel> seedCollecteurs = [
  CollecteurModel(
    id: 'co1',
    name: 'Paul Mbarga',
    phone: '+237 678 90 11 22',
    zone: 'Bonanjo / Akwa',
    rating: 4.8,
    status: 'Active',
  ),
  CollecteurModel(
    id: 'co2',
    name: 'Vincent Onana',
    phone: '+237 693 55 44 33',
    zone: 'Bonapriso / Bali',
    rating: 4.5,
    status: 'Active',
  ),
  CollecteurModel(
    id: 'co3',
    name: 'André Kamdem',
    phone: '+237 657 22 19 88',
    zone: 'Deido',
    rating: 4.2,
    status: 'Inactive',
  ),
  CollecteurModel(
    id: 'co4',
    name: 'Serge Ateba',
    phone: '+237 690 10 55 40',
    zone: 'Ndogbong',
    rating: 4.9,
    status: 'Active',
  ),
];

const List<ContratModel> seedContrats = [
  ContratModel(
    id: 'ct1',
    client: 'Jean Dooh',
    frequence: 'Twice a week (2x/week)',
    prix: 8000,
    status: 'Active',
  ),
  ContratModel(
    id: 'ct2',
    client: 'Marie Ekwalla',
    frequence: 'Twice a week (2x/week)',
    prix: 12000,
    status: 'Active',
  ),
  ContratModel(
    id: 'ct3',
    client: 'Samuel Njoya',
    frequence: 'Weekly (1x/week)',
    prix: 5000,
    status: 'Suspended',
  ),
  ContratModel(
    id: 'ct4',
    client: 'Aïcha Bello',
    frequence: 'Twice a week (2x/week)',
    prix: 8000,
    status: 'Active',
  ),
  ContratModel(
    id: 'ct5',
    client: 'Patrice Fotso',
    frequence: 'Twice a week (2x/week)',
    prix: 12000,
    status: 'Active',
  ),
  ContratModel(
    id: 'ct6',
    client: 'Éric Tchoua',
    frequence: 'Monthly',
    prix: 4000,
    status: 'Expired',
  ),
];

const List<CollecteModel> seedCollectes = [
  CollecteModel(
    id: 'cc1',
    client: 'Jean Dooh',
    collecteur: 'Paul Mbarga',
    date: '2026-08-04',
    poids: 4.2,
    status: 'Completed',
  ),
  CollecteModel(
    id: 'cc2',
    client: 'Marie Ekwalla',
    collecteur: 'Vincent Onana',
    date: '2026-08-04',
    poids: 5.1,
    status: 'Completed',
  ),
  CollecteModel(
    id: 'cc3',
    client: 'Aïcha Bello',
    collecteur: 'Paul Mbarga',
    date: '2026-08-05',
    poids: 0,
    status: 'Scheduled',
  ),
  CollecteModel(
    id: 'cc4',
    client: 'Patrice Fotso',
    collecteur: 'Vincent Onana',
    date: '2026-08-05',
    poids: 0,
    status: 'Scheduled',
  ),
  CollecteModel(
    id: 'cc5',
    client: 'Samuel Njoya',
    collecteur: 'André Kamdem',
    date: '2026-08-01',
    poids: 0,
    status: 'Missed',
  ),
  CollecteModel(
    id: 'cc6',
    client: 'Sarah Mbida',
    collecteur: 'Serge Ateba',
    date: '2026-08-03',
    poids: 3.4,
    status: 'Completed',
  ),
];

const List<FactureModel> seedFactures = [
  FactureModel(
    id: 'fa1',
    client: 'Jean Dooh',
    montant: 8000,
    echeance: '2026-08-10',
    status: 'Paid',
  ),
  FactureModel(
    id: 'fa2',
    client: 'Marie Ekwalla',
    montant: 12000,
    echeance: '2026-08-12',
    status: 'Pending',
  ),
  FactureModel(
    id: 'fa3',
    client: 'Samuel Njoya',
    montant: 5000,
    echeance: '2026-07-28',
    status: 'Overdue',
  ),
  FactureModel(
    id: 'fa4',
    client: 'Aïcha Bello',
    montant: 8000,
    echeance: '2026-08-15',
    status: 'Paid',
  ),
  FactureModel(
    id: 'fa5',
    client: 'Patrice Fotso',
    montant: 12000,
    echeance: '2026-08-14',
    status: 'Pending',
  ),
];

const List<FrequenceModel> seedFrequences = [
  FrequenceModel(id: 'fr1', libelle: 'Weekly (1x/week)', jours: 7),
  FrequenceModel(id: 'fr2', libelle: 'Twice a week (2x/week)', jours: 3),
  FrequenceModel(id: 'fr3', libelle: 'Monthly', jours: 30),
];

/// Activity feed entries (design's `activity` array).
const List<({String color, String text, String time})> seedActivity = [
  (color: '#1E9E5A', text: 'Pickup completed at Jean Dooh', time: '12 min ago'),
  (color: '#E8A33D', text: 'New client registered: Sarah Mbida', time: '40 min ago'),
  (color: '#C1443D', text: 'Pickup missed at Samuel Njoya', time: '1 h ago'),
  (color: '#3D6BE8', text: 'Payment received from Aïcha Bello — 8,000 XAF', time: '2 h ago'),
];
