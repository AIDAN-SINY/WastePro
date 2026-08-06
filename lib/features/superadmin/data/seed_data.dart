import '../../../models/agence_model.dart';
import '../../../models/platform_user_model.dart';
import '../../../models/societe_model.dart';

/// Default platform data (same entities as `super-admin-desktop.html`).
///
/// Used by [PlatformStore] as its in-memory dataset and by the
/// Firestore-backed store to seed empty collections on first run.
const List<SocieteModel> seedSocietes = [
  SocieteModel(
    id: 'so1',
    raisonSociale: 'Propre237 Douala SARL',
    adresse: 'Bonanjo, Douala',
    telephone: '+237 233 42 10 10',
    email: 'contact@propre237-douala.cm',
    status: 'Actif',
  ),
  SocieteModel(
    id: 'so2',
    raisonSociale: 'Propre237 Yaoundé SA',
    adresse: 'Bastos, Yaoundé',
    telephone: '+237 222 20 30 40',
    email: 'contact@propre237-yde.cm',
    status: 'Actif',
  ),
  SocieteModel(
    id: 'so3',
    raisonSociale: 'EcoCollecte Kribi',
    adresse: 'Centre-ville, Kribi',
    telephone: '+237 233 46 12 00',
    email: 'contact@ecocollecte-kribi.cm',
    status: 'Suspendu',
  ),
];

const List<AgenceModel> seedAgences = [
  AgenceModel(
    id: 'ag1',
    societe: 'Propre237 Douala SARL',
    ville: 'Douala — Bonanjo',
    responsable: 'Jean Dooh',
    telephone: '+237 677 12 34 56',
    status: 'Actif',
  ),
  AgenceModel(
    id: 'ag2',
    societe: 'Propre237 Douala SARL',
    ville: 'Douala — Bassa',
    responsable: 'Aïcha Bello',
    telephone: '+237 699 33 67 41',
    status: 'Actif',
  ),
  AgenceModel(
    id: 'ag3',
    societe: 'Propre237 Yaoundé SA',
    ville: 'Yaoundé',
    responsable: 'Marie Ekwalla',
    telephone: '+237 690 45 12 78',
    status: 'Actif',
  ),
  AgenceModel(
    id: 'ag4',
    societe: 'EcoCollecte Kribi',
    ville: 'Kribi',
    responsable: 'Samuel Njoya',
    telephone: '+237 655 88 21 09',
    status: 'Suspendu',
  ),
];

const List<PlatformUserModel> seedUtilisateurs = [
  PlatformUserModel(
    id: 'us1',
    nom: 'Jean Dooh',
    telephone: '+237 677 12 34 56',
    role: "Responsable d'Agence",
    agence: 'Douala — Bonanjo',
    status: 'Actif',
  ),
  PlatformUserModel(
    id: 'us2',
    nom: 'Aïcha Bello',
    telephone: '+237 699 33 67 41',
    role: "Responsable d'Agence",
    agence: 'Douala — Bassa',
    status: 'Actif',
  ),
  PlatformUserModel(
    id: 'us3',
    nom: 'Marie Ekwalla',
    telephone: '+237 690 45 12 78',
    role: "Responsable d'Agence",
    agence: 'Yaoundé',
    status: 'Actif',
  ),
  PlatformUserModel(
    id: 'us4',
    nom: 'Admin Plateforme',
    telephone: '+237 6XX XXX XXX',
    role: 'Administrateur Général',
    agence: '—',
    status: 'Actif',
  ),
];
