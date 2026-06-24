/// All user-visible strings in one place for easy localization.
abstract final class AppStrings {
  // ── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'JTR System';
  static const String jtrSystem = 'JTR SYSTEM';
  static const String jtrBrand = 'JTR';
  static const String jtrRest = ' SYSTEM';

  // ── Home screen ──────────────────────────────────────────────────────────
  static const String connect = 'Connect';
  static const String exit = 'Exit';

  // ── Legal / footer ───────────────────────────────────────────────────────
  static const String rightsLine1 =
      'All rights and license granted by JTR Ennovation.';
  static const String rightsLine2 =
      'Contact: +212 8 08 58 51 28 / +212 6 66 44 43 30';
  static const String rightsEmail = 'contact.jtrinnovation@gmail.com';
  static const String rightsEmailNote = '"to be modified"';

  // ── Auth / Connection screen ─────────────────────────────────────────────
  static const String connexion = 'CONNEXION';
  static const String manager = 'MANAGER';
  static const String motDePasse = 'Mot de passe';
  static const String seConnecter = 'Se connecter';
  static const String back = 'Back';

  // ── Dashboard ────────────────────────────────────────────────────────────
  static const String surPlace = 'SUR PLACE';
  static const String roleLabelManager = 'Manager';

  // ── Table headers ────────────────────────────────────────────────────────
  static const String headerNum = 'N°';
  static const String headerGuests = 'G.';
  static const String headerPost = 'POSTE';
  static const String headerCtrProfit = 'CTR.\nPROFIT';
  static const String headerCover = 'CVT.';
  static const String headerImp = 'IMP.';
  static const String headerTotal = 'TOTAL';

  // ── Footer action buttons ────────────────────────────────────────────────
  static const String newOrder = 'NOUVELLE\nCOMMANDE';
  static const String requestNext = 'DEMANDER\nLA SUITE';
  static const String ticket = 'TICKET';
  static const String statistics = 'Statistics';

  // ── Loading screen ───────────────────────────────────────────────────────
  static const String connexionEtablie = 'Connexion établie';

  // ── Navigation / dialogs ─────────────────────────────────────────────────
  static const String exitTitle = 'Quitter l\'application';
  static const String exitMessage = 'Voulez-vous vraiment quitter JTR System ?';
  static const String logoutTitle = 'Déconnexion';
  static const String logoutMessage =
      'Voulez-vous vous déconnecter et retourner à l\'accueil ?';
  static const String aboutTitle = 'À propos';
  static const String aboutMessage =
      'JTR System — Order Taking App\nVersion 1.0.0';

  // ── Order flows ──────────────────────────────────────────────────────────
  static const String orderDetail = 'Détail commande';
  static const String orderNotFound = 'Commande introuvable';
  static const String newOrderTitle = 'Nouvelle commande';
  static const String requestNextTitle = 'Demander la suite';
  static const String requestNextShort = 'La suite';
  static const String requestNextDescription =
      'Sélectionnez la table pour demander le plat suivant.';
  static const String sendRequest = 'Envoyer la demande';
  static const String requestSent = 'Demande envoyée pour';
  static const String noActiveTables = 'Aucune table active pour le moment.';
  static const String ticketTitle = 'Ticket';
  static const String printTicket = 'Imprimer le ticket';
  static const String ticketPrinted = 'Ticket imprimé pour';
  static const String statisticsTitle = 'Statistiques';
  static const String statRevenue = 'Chiffre d\'affaires';
  static const String statOpenTables = 'Tables ouvertes';
  static const String statPrintedTickets = 'Tickets imprimés';
  static const String statTablesBreakdown = 'Détail par table';
  static const String tableAvailable = 'Table disponible';
  static const String tableOccupied = 'Table occupée';
  static const String tableLabel = 'Table';
  static const String totalLabel = 'Total';
  static const String guestsLabel = 'couverts';
  static const String imprimesLabel = 'imprimés';
}
