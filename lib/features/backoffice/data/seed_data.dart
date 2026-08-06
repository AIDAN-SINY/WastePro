import '../models.dart';

/// Default backoffice data (same entities as `backoffice-mobile.html`).
const List<ClientModel> seedClients = [
  ClientModel(
    id: 'cl1',
    name: 'Jean Dooh',
    phone: '+237 677 12 34 56',
    zone: 'Bonanjo',
    plan: 'Standard',
    status: 'Actif',
  ),
  ClientModel(
    id: 'cl2',
    name: 'Marie Ekwalla',
    phone: '+237 690 45 12 78',
    zone: 'Akwa',
    plan: 'Premium',
    status: 'Actif',
  ),
  ClientModel(
    id: 'cl3',
    name: 'Samuel Njoya',
    phone: '+237 655 88 21 09',
    zone: 'Bonapriso',
    plan: 'Essentiel',
    status: 'Suspendu',
  ),
  ClientModel(
    id: 'cl4',
    name: 'Aïcha Bello',
    phone: '+237 699 33 67 41',
    zone: 'Deido',
    plan: 'Standard',
    status: 'Actif',
  ),
  ClientModel(
    id: 'cl5',
    name: 'Patrice Fotso',
    phone: '+237 674 20 15 63',
    zone: 'Bali',
    plan: 'Premium',
    status: 'Actif',
  ),
  ClientModel(
    id: 'cl6',
    name: 'Sarah Mbida',
    phone: '+237 691 77 04 22',
    zone: 'Bonanjo',
    plan: 'Essentiel',
    status: 'Actif',
  ),
  ClientModel(
    id: 'cl7',
    name: 'Éric Tchoua',
    phone: '+237 656 40 88 15',
    zone: 'Ndogbong',
    plan: 'Standard',
    status: 'Suspendu',
  ),
];

const List<CollecteurModel> seedCollecteurs = [
  CollecteurModel(
    id: 'co1',
    name: 'Paul Mbarga',
    phone: '+237 678 90 11 22',
    zone: 'Bonanjo / Akwa',
    rating: 4.8,
    status: 'Actif',
  ),
  CollecteurModel(
    id: 'co2',
    name: 'Vincent Onana',
    phone: '+237 693 55 44 33',
    zone: 'Bonapriso / Bali',
    rating: 4.5,
    status: 'Actif',
  ),
  CollecteurModel(
    id: 'co3',
    name: 'André Kamdem',
    phone: '+237 657 22 19 88',
    zone: 'Deido',
    rating: 4.2,
    status: 'Inactif',
  ),
  CollecteurModel(
    id: 'co4',
    name: 'Serge Ateba',
    phone: '+237 690 10 55 40',
    zone: 'Ndogbong',
    rating: 4.9,
    status: 'Actif',
  ),
];

const List<ContratModel> seedContrats = [
  ContratModel(
    id: 'ct1',
    client: 'Jean Dooh',
    frequence: 'Bi-hebdomadaire (2x/semaine)',
    prix: 8000,
    status: 'Actif',
  ),
  ContratModel(
    id: 'ct2',
    client: 'Marie Ekwalla',
    frequence: 'Bi-hebdomadaire (2x/semaine)',
    prix: 12000,
    status: 'Actif',
  ),
  ContratModel(
    id: 'ct3',
    client: 'Samuel Njoya',
    frequence: 'Hebdomadaire (1x/semaine)',
    prix: 5000,
    status: 'Suspendu',
  ),
  ContratModel(
    id: 'ct4',
    client: 'Aïcha Bello',
    frequence: 'Bi-hebdomadaire (2x/semaine)',
    prix: 8000,
    status: 'Actif',
  ),
  ContratModel(
    id: 'ct5',
    client: 'Patrice Fotso',
    frequence: 'Bi-hebdomadaire (2x/semaine)',
    prix: 12000,
    status: 'Actif',
  ),
  ContratModel(
    id: 'ct6',
    client: 'Éric Tchoua',
    frequence: 'Mensuel',
    prix: 4000,
    status: 'Expiré',
  ),
];

const List<CollecteModel> seedCollectes = [
  CollecteModel(
    id: 'cc1',
    client: 'Jean Dooh',
    collecteur: 'Paul Mbarga',
    date: '2026-08-04',
    poids: 4.2,
    status: 'Effectué',
  ),
  CollecteModel(
    id: 'cc2',
    client: 'Marie Ekwalla',
    collecteur: 'Vincent Onana',
    date: '2026-08-04',
    poids: 5.1,
    status: 'Effectué',
  ),
  CollecteModel(
    id: 'cc3',
    client: 'Aïcha Bello',
    collecteur: 'Paul Mbarga',
    date: '2026-08-05',
    poids: 0,
    status: 'Prévu',
  ),
  CollecteModel(
    id: 'cc4',
    client: 'Patrice Fotso',
    collecteur: 'Vincent Onana',
    date: '2026-08-05',
    poids: 0,
    status: 'Prévu',
  ),
  CollecteModel(
    id: 'cc5',
    client: 'Samuel Njoya',
    collecteur: 'André Kamdem',
    date: '2026-08-01',
    poids: 0,
    status: 'Manqué',
  ),
  CollecteModel(
    id: 'cc6',
    client: 'Sarah Mbida',
    collecteur: 'Serge Ateba',
    date: '2026-08-03',
    poids: 3.4,
    status: 'Effectué',
  ),
];

const List<FactureModel> seedFactures = [
  FactureModel(
    id: 'fa1',
    client: 'Jean Dooh',
    montant: 8000,
    echeance: '2026-08-10',
    status: 'Payée',
  ),
  FactureModel(
    id: 'fa2',
    client: 'Marie Ekwalla',
    montant: 12000,
    echeance: '2026-08-12',
    status: 'En attente',
  ),
  FactureModel(
    id: 'fa3',
    client: 'Samuel Njoya',
    montant: 5000,
    echeance: '2026-07-28',
    status: 'En retard',
  ),
  FactureModel(
    id: 'fa4',
    client: 'Aïcha Bello',
    montant: 8000,
    echeance: '2026-08-15',
    status: 'Payée',
  ),
  FactureModel(
    id: 'fa5',
    client: 'Patrice Fotso',
    montant: 12000,
    echeance: '2026-08-14',
    status: 'En attente',
  ),
];

const List<FrequenceModel> seedFrequences = [
  FrequenceModel(id: 'fr1', libelle: 'Hebdomadaire (1x/semaine)', jours: 7),
  FrequenceModel(id: 'fr2', libelle: 'Bi-hebdomadaire (2x/semaine)', jours: 3),
  FrequenceModel(id: 'fr3', libelle: 'Mensuel', jours: 30),
];

/// Activity feed entries (design's `activity` array).
const List<({String color, String text, String time})> seedActivity = [
  (color: '#1E9E5A', text: 'Ramassage effectué chez Jean Dooh', time: 'il y a 12 min'),
  (color: '#E8A33D', text: 'Nouveau client inscrit : Sarah Mbida', time: 'il y a 40 min'),
  (color: '#C1443D', text: 'Ramassage manqué chez Samuel Njoya', time: 'il y a 1 h'),
  (color: '#3D6BE8', text: 'Paiement reçu de Aïcha Bello — 8 000 XAF', time: 'il y a 2 h'),
];
