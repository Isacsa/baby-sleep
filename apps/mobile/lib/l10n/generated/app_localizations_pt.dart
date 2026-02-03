// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Baby Sleep';

  @override
  String get tabSleep => 'Sono';

  @override
  String get tabStats => 'Estatísticas';

  @override
  String get tabRelax => 'Relaxar';

  @override
  String get tabInsights => 'Insights';

  @override
  String get homeGreeting => 'Olá, como correu a noite?';

  @override
  String homeBabyName(String name) {
    return 'Bebé $name';
  }

  @override
  String get homeSleepNow => 'Dormir Agora';

  @override
  String get homeWakeUp => 'Acordou';

  @override
  String get homeStartedAgo => 'Começar há:';

  @override
  String get homeOtherTime => 'Outra hora';

  @override
  String get homeRegisterPastSleep => 'Registar sono anterior:';

  @override
  String get homeOtherTimePast => 'Outra hora (sono anterior)';

  @override
  String get dayToday => 'Hoje';

  @override
  String get dayYesterday => 'Ontem';

  @override
  String dayTodayWithDate(int day, String month) {
    return 'Hoje, $day $month';
  }

  @override
  String dayYesterdayWithDate(int day, String month) {
    return 'Ontem, $day $month';
  }

  @override
  String get sessionsSleep => 'Sessões de sono';

  @override
  String sessionsCount(int count) {
    return '$count registos';
  }

  @override
  String get sessionNap => 'Sesta';

  @override
  String get sessionNight => 'Sono noturno';

  @override
  String get sessionCrossMidnight => 'Atravessa meia-noite';

  @override
  String get sessionStartedYesterday => 'Começou ontem';

  @override
  String get sessionOngoing => 'A dormir...';

  @override
  String get sessionInProgress => 'em curso';

  @override
  String get emptyStateNoRecords => 'Ainda sem registos hoje';

  @override
  String get emptyStateRecordsWillAppear =>
      'Os registos de sono aparecerão aqui';

  @override
  String get statsTitle => 'Estatísticas';

  @override
  String get statsWeek => 'Semana';

  @override
  String get statsMonth => 'Mês';

  @override
  String get statsNoData => 'Ainda sem dados';

  @override
  String get statsAvgPerDay => 'Média/dia';

  @override
  String get statsTotalNaps => 'Total sestas';

  @override
  String get statsDaysRecorded => 'Dias registados';

  @override
  String get statsPeriodDay => 'Dia';

  @override
  String get statsPeriod14Days => '14 dias';

  @override
  String get statsPeriodCustom => 'Custom';

  @override
  String statsPeriodLabel(int days) {
    return 'Últimos $days dias';
  }

  @override
  String get statsTypeAll => 'Tudo';

  @override
  String get statsTypeNight => 'Noite';

  @override
  String get statsTypeNaps => 'Sestas';

  @override
  String get statsCompare => 'Comparar';

  @override
  String get statsExport => 'Exportar';

  @override
  String get statsBasedOnLocalData => 'Baseado em dados locais';

  @override
  String get statsComparedWithPrevious => 'comparado com período anterior';

  @override
  String get statsDataQualityGood => 'Boa';

  @override
  String get statsDataQualityPartial => 'Parcial';

  @override
  String get statsDataQualityIncomplete => 'Incompleta';

  @override
  String get statsDataQualityDetails => 'Ver detalhes';

  @override
  String get statsDataQualityTitle => 'Qualidade dos dados';

  @override
  String get statsDataQualityGoodDesc => 'Dados completos e consistentes';

  @override
  String get statsDataQualityPartialDesc => 'Pode haver subestimação';

  @override
  String get statsDataQualityIncompleteDesc =>
      'Dados insuficientes para análise precisa';

  @override
  String statsDataQualityIssueMissingDays(int count) {
    return '$count dias sem registos';
  }

  @override
  String get statsDataQualityIssueOngoingLong => 'Sono em curso há mais de 18h';

  @override
  String statsDataQualityIssueImprobable(int count) {
    return '$count durações improváveis';
  }

  @override
  String statsDataQualityIssueOverlaps(int count) {
    return '$count sobreposições detetadas';
  }

  @override
  String get statsDataQualityActionReviewDay => 'Rever dia';

  @override
  String get statsDataQualityActionEndSleep => 'Terminar sono';

  @override
  String get statsDataQualityActionEditSession => 'Editar sessão';

  @override
  String get statsKpiMedianTotal => 'Mediana/dia';

  @override
  String get statsKpiNightVsNaps => 'Noite vs Sestas';

  @override
  String get statsKpiLongestBlock => 'Maior bloco';

  @override
  String get statsKpiFragmentation => 'Fragmentação';

  @override
  String get statsKpiBedtimeConsistency => 'Consistência hora deitar';

  @override
  String get statsKpiEpisodesPerNight => 'episódios/noite';

  @override
  String get statsKpiNoEnoughData => 'Dados insuficientes';

  @override
  String get statsChartTotalPerDay => 'Total de sono por dia';

  @override
  String get statsChartNightVsNaps => 'Noite vs Sestas';

  @override
  String get statsChartBedtimeConsistency => 'Hora de deitar';

  @override
  String get statsChartNapDistribution => 'Distribuição das sestas';

  @override
  String get statsChartNapShort => '<30m';

  @override
  String get statsChartNap30to60 => '30-60m';

  @override
  String get statsChartNap60to90 => '60-90m';

  @override
  String get statsChartNapLong => '>90m';

  @override
  String get statsTimelineTitle => 'Timeline';

  @override
  String get statsTimelineEmpty => 'Sem registos neste dia';

  @override
  String get statsTimelineIncomplete => 'Dados incompletos';

  @override
  String get statsTimelineOngoing => 'Sono em curso';

  @override
  String get statsTimelineOverlap => 'Sobreposição';

  @override
  String get statsExportTitle => 'Exportar dados';

  @override
  String get statsExportPdf => 'PDF';

  @override
  String get statsExportCsv => 'CSV';

  @override
  String get statsExportPeriod7 => '7 dias';

  @override
  String get statsExportPeriod14 => '14 dias';

  @override
  String get statsExportPeriod30 => '30 dias';

  @override
  String get statsExportPeriodCustom => 'Período selecionado';

  @override
  String get statsExportCsvSessions => 'Sessões';

  @override
  String get statsExportCsvAggregates => 'Agregados diários';

  @override
  String get statsExportCsvBoth => 'Ambos';

  @override
  String get statsExportIncludeName => 'Incluir nome do bebé';

  @override
  String get statsExportGenerate => 'Gerar e partilhar';

  @override
  String get statsExportPreviewPdf => 'Resumo com KPIs, gráficos e timeline';

  @override
  String get statsExportPreviewCsv => 'Dados em formato tabular para análise';

  @override
  String get statsEmptyState => 'Ainda sem registos de sono';

  @override
  String get statsEmptyStateCta => 'Ir para Sono';

  @override
  String get statsGoToSleep => 'Registar sono';

  @override
  String get relaxTitle => 'Relaxar';

  @override
  String get relaxComingSoon => 'Em breve';

  @override
  String get relaxModeNow => 'Modo Agora';

  @override
  String get relaxNightMode => 'Modo noite';

  @override
  String get relaxNightModeBadge => 'Noite';

  @override
  String get relaxSounds => 'Sons';

  @override
  String get relaxQuickGuides => 'Guias rápidos';

  @override
  String get relaxSleepShortcuts => 'Atalhos de sono';

  @override
  String get relaxSoundWhiteNoise => 'Ruído Branco';

  @override
  String get relaxSoundRain => 'Chuva';

  @override
  String get relaxSoundFan => 'Ventoinha';

  @override
  String get relaxSoundShush => 'Shushing';

  @override
  String get relaxPlay => 'Reproduzir';

  @override
  String get relaxPause => 'Pausar';

  @override
  String get relaxStop => 'Parar';

  @override
  String get relaxResume => 'Retomar';

  @override
  String get relaxVolume => 'Volume';

  @override
  String get relaxVolumeLow => 'baixo';

  @override
  String get relaxVolumeHigh => 'alto';

  @override
  String get relaxVolumeHighWarning =>
      'Se o indicador estiver na zona alta, considera baixar o volume.';

  @override
  String get relaxVolumeSafetyTip =>
      'Volume baixo e dispositivo afastado do berço.';

  @override
  String get relaxTimer => 'Timer';

  @override
  String get relaxTimerInfinite => '∞';

  @override
  String relaxTimerMinutes(int minutes) {
    return '${minutes}min';
  }

  @override
  String get relaxFadeOut => 'Fade-out';

  @override
  String get relaxFadeOutEnabled => 'ativado';

  @override
  String get relaxFadeOutDisabled => 'desativado';

  @override
  String get relaxDarkScreen => 'Ecrã escuro';

  @override
  String get relaxSaveConfig => 'Guardar configuração';

  @override
  String get relaxFavorites => 'Favoritos';

  @override
  String get relaxNoFavorites => 'Ainda sem favoritos';

  @override
  String get relaxFavoriteSaved => 'Configuração guardada nos favoritos';

  @override
  String get relaxFavoriteRemoved => 'Removido dos favoritos';

  @override
  String get relaxSafetyChecklist => 'Checklist sono seguro';

  @override
  String get relaxSafetyChecklistShort => 'Checklist (10s)';

  @override
  String get relaxBreathing60s => 'Respiração 60s';

  @override
  String get relaxGoToSleep => 'Ir para Sono';

  @override
  String get relaxStartSleep => 'Começar sono';

  @override
  String get relaxEndSleep => 'Terminar sono';

  @override
  String get relaxSleepOngoing => 'Sono em curso';

  @override
  String get relaxAwake => 'Acordado';

  @override
  String get relaxAudioUnavailable =>
      'Áudio indisponível neste dispositivo. Continua a usar os guias abaixo.';

  @override
  String get relaxAudioError => 'Não foi possível iniciar o áudio.';

  @override
  String get relaxTryAgain => 'Tentar novamente';

  @override
  String get relaxHelp => 'Ajuda';

  @override
  String get relaxInterrupted => 'Reprodução interrompida';

  @override
  String get relaxBackgroundWarning =>
      'Em background, o som pode parar neste dispositivo. Mantém a app aberta para continuar.';

  @override
  String get relaxDisclaimer =>
      'Isto é apoio prático e seguro. Não garante sono. Se tiveres preocupações médicas, fala com um profissional.';

  @override
  String get relaxSofaWarning =>
      'Evita adormecer com o bebé no sofá/cadeirão — é um dos cenários de maior risco.';

  @override
  String get relaxSafetyNote =>
      'Se estiveres com sono, coloca o bebé num local seguro.';

  @override
  String get relaxSources => 'Fontes: AAP/CDC/NHS.';

  @override
  String get babiesTitle => 'Bebés';

  @override
  String get babiesAddNew => 'Adicionar bebé';

  @override
  String get babiesNoBabies => 'Ainda sem bebés adicionados';

  @override
  String babiesAge(int months) {
    return '$months meses';
  }

  @override
  String babiesAgeYears(int years) {
    return '$years ano(s)';
  }

  @override
  String get babiesPullGlobal => 'Puxar bebés (Global)';

  @override
  String get babiesNew => 'Novo';

  @override
  String get babiesErrorLoading => 'Erro ao carregar bebés';

  @override
  String get babiesNameLabel => 'Nome do bebé';

  @override
  String get babiesNameHint => 'ex.: Maria';

  @override
  String babiesCreatedSuccess(String name) {
    return 'Bebé \"$name\" criado';
  }

  @override
  String babiesCreatedError(String error) {
    return 'Falha ao criar bebé: $error';
  }

  @override
  String get menuLogout => 'Sair';

  @override
  String get menuDebug => 'Debug';

  @override
  String get loginTitle => 'Bem-vindo';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Entrar';

  @override
  String get loginRegister => 'Criar conta';

  @override
  String get loginUseDifferentEmail => 'Usar outro email';

  @override
  String get loginInvalidEmail => 'Por favor, insere um email válido';

  @override
  String get loginMagicLinkSent =>
      'Link mágico enviado! Verifica o teu email e clica no link para entrar.';

  @override
  String get loginMagicLinkFailed =>
      'Falha ao enviar o link. Por favor, tenta novamente.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonRetry => 'Tentar';

  @override
  String get commonOk => 'OK';

  @override
  String get summaryTotalSleep => 'Sono total';

  @override
  String get totalLabel => 'total';

  @override
  String summaryNaps(int count) {
    return '$count sestas';
  }

  @override
  String summarySessions(int count) {
    return '$count sessões';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get errorGeneric => 'Ocorreu um erro';

  @override
  String get errorNetwork => 'Erro de rede. Verifica a tua ligação.';

  @override
  String get errorNoBaby => 'Nenhum bebé selecionado';

  @override
  String get syncSyncing => 'A sincronizar...';

  @override
  String get syncSynced => 'Sincronizado';

  @override
  String get syncOffline => 'Offline';

  @override
  String syncPending(int count) {
    return '$count pendentes';
  }

  @override
  String get editSleepTitle => 'Editar sono';

  @override
  String get editSleepStart => 'Início';

  @override
  String get editSleepEnd => 'Fim';

  @override
  String get editSleepEndAfterStart =>
      'A hora de fim deve ser depois do início';

  @override
  String get editSleepSuccess => 'Sono editado';

  @override
  String errorWithMessage(String message) {
    return 'Erro: $message';
  }

  @override
  String get overlapOtherSleep => 'Sobrepõe outro sono';

  @override
  String overlapNewPeriodMessage(String sessions) {
    return 'O novo período sobrepõe: $sessions\n\nQueres substituir?';
  }

  @override
  String sinceSomething(String time) {
    return 'desde $time';
  }

  @override
  String get deleteSleepTitle => 'Eliminar sono?';

  @override
  String deleteSleepConfirm(String start, String end) {
    return 'Tens a certeza que queres eliminar o sono das $start às $end?';
  }

  @override
  String get deleteSleepSuccess => 'Sono eliminado';

  @override
  String get overlapTitle => 'Já existe sono registado';

  @override
  String get overlapReplace => 'Substituir sono existente';

  @override
  String get overlapReplaced => 'Sono substituído';

  @override
  String get dstInvalidTime => 'Hora inválida';

  @override
  String dstTimeNotExist(String time) {
    return 'A hora $time não existe neste dia devido à mudança de hora (DST).\n\nPor favor, escolhe outra hora.';
  }

  @override
  String get preparingPermissions => 'A preparar permissões...';

  @override
  String get selectBaby => 'Seleciona um bebé';

  @override
  String get whatDay => 'Que dia?';

  @override
  String chosenTime(String time) {
    return 'Hora escolhida: $time';
  }

  @override
  String todayIsFuture(String time) {
    return 'Hoje às $time ainda é futuro';
  }

  @override
  String get otherDay => 'Outro dia…';

  @override
  String get cannotRegisterFuture => 'Não é possível registar sono no futuro';

  @override
  String get whatToRegister => 'O que queres registar?';

  @override
  String startAtTime(String day, String time) {
    return 'Início: $day às $time';
  }

  @override
  String get stillSleeping => 'Ainda está a dormir';

  @override
  String get registerCompleteSleep => 'Registar sono completo';

  @override
  String sleepingSince(String time) {
    return 'Já está a dormir desde $time';
  }

  @override
  String get whatToDo => 'O que queres fazer?';

  @override
  String get endSleepNow => 'Terminar sono agora';

  @override
  String get registerPastCompleteSleep => 'Registar sono completo do passado';

  @override
  String get sleepEnded => 'Sono terminado';

  @override
  String get whenSleepStarted => 'Quando começou o sono?';

  @override
  String get whenWokeUp => 'Quando acordou?';

  @override
  String get startTimeHelp => 'Hora de início do sono';

  @override
  String get endTimeHelp => 'Hora de fim do sono';

  @override
  String get startCannotBeFuture => 'A hora de início não pode estar no futuro';

  @override
  String get crossedMidnight => 'Atravessou meia-noite?';

  @override
  String crossedMidnightQuestion(String start, String end) {
    return 'Início às $start e fim às $end.\n\nO sono atravessou a meia-noite (dormiu ontem à noite, acordou hoje de manhã)?';
  }

  @override
  String get noCorrect => 'Não, corrigir';

  @override
  String get yes => 'Sim';

  @override
  String get endInFuture => 'Hora de fim no futuro';

  @override
  String get endCannotBeFuture => 'A hora de fim não pode estar no futuro.';

  @override
  String get useNow => 'Usar agora';

  @override
  String get syncTitle => 'Sincronização';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get menuSwitchBaby => 'Mudar bebé';

  @override
  String get unknownTime => 'hora desconhecida';

  @override
  String ongoingSince(String time) {
    return 'desde $time (em curso)';
  }

  @override
  String get overlapMessage =>
      'O novo registo sobrepõe-se a este(s) sono(s). Queres substituir?';

  @override
  String errorOverwriting(String error) {
    return 'Erro ao substituir: $error';
  }

  @override
  String get pickDay => 'Escolher dia';

  @override
  String get noPermissionToCreate => 'Não tens permissão para criar eventos.';

  @override
  String get preparingPermissionsWait =>
      'A preparar permissões. Aguarda um momento.';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Fev';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Abr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Ago';

  @override
  String get monthSep => 'Set';

  @override
  String get monthOct => 'Out';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dez';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsHeaderToday => 'Hoje';

  @override
  String insightsHeaderBasedOn(int days) {
    return 'Baseado em $days dias';
  }

  @override
  String get insightsHeaderPatterns => 'Padrões detetados';

  @override
  String get insightsHeaderRoutine => 'Rotina sugerida';

  @override
  String get insightsHeaderGuide => 'Guia';

  @override
  String get insightsAddDob => 'Adicionar data de nascimento';

  @override
  String get insightsAddDobBanner =>
      'Para personalizar insights por idade, adiciona a data de nascimento';

  @override
  String get insightsAddNow => 'Adicionar agora';

  @override
  String get insightsMainPoint => 'Ponto principal';

  @override
  String get insightsNextStep => 'Próximo passo';

  @override
  String get insightsSavedFavorites => 'Guardado nos favoritos';

  @override
  String get insightsSuggestionLabel => 'sugestão';

  @override
  String get insightsDefineDobForAge =>
      'Define a data de nascimento para sugestões por idade.';

  @override
  String get insightsToSeePersonalized => 'Para ver insights personalizados.';

  @override
  String get insightsNoRecordsYet => 'Ainda não há registos de sono';

  @override
  String get insightsRecordFirstSleep =>
      'Regista o primeiro sono na aba \"Sono\" para começar a ver insights.';

  @override
  String get insightsRegisterSleep => 'Registar sono';

  @override
  String get insightsCollectingPatterns =>
      'Ainda a recolher dados para identificar padrões.';

  @override
  String get insightsRegisterMoreNights =>
      'Regista mais algumas noites para receber sugestões de rotina personalizadas.';

  @override
  String insightsVsAvg7Days(String diff) {
    return '$diff vs média 7 dias';
  }

  @override
  String get insightsNoDobFallback => 'Insights gerais (sem faixa etária)';

  @override
  String get insightsLearning => 'Ainda a aprender o padrão do teu bebé';

  @override
  String get insightsMoreDataNeeded =>
      'Precisamos de mais alguns dias de dados';

  @override
  String get insightsSourcesTitle => 'Fontes';

  @override
  String get insightsDisclaimerMedical =>
      'Este conteúdo é informativo e não substitui aconselhamento médico.';

  @override
  String get insightSummary24hTitle => 'Resumo 24h';

  @override
  String insightSummary24hBody(int hours, int minutes) {
    return 'Sono total: ${hours}h ${minutes}m';
  }

  @override
  String insightSummary24hVsAvg(String sign, int minutes) {
    return '$sign${minutes}m vs média 7 dias';
  }

  @override
  String get insightSummary24hNoData => 'Ainda sem dados suficientes';

  @override
  String get insightCurrentlySleepingTitle => 'A dormir';

  @override
  String insightCurrentlySleepingBody(String time) {
    return 'A dormir desde $time';
  }

  @override
  String get insightSleepBelowExpectedTitle => 'Sono abaixo do esperado';

  @override
  String get insightSleepBelowExpectedBody =>
      'O sono nas últimas 24h está ligeiramente abaixo do recomendado para a idade.';

  @override
  String insightSleepBelowExpectedWhy(int min, int max) {
    return 'Comparado com o intervalo típico ($min–${max}h).';
  }

  @override
  String get insightSleepWithinExpectedTitle => 'Sono dentro do esperado';

  @override
  String get insightSleepWithinExpectedBody =>
      'O sono está dentro do intervalo recomendado para esta idade.';

  @override
  String get insightSleepAboveExpectedTitle => 'Sono acima do esperado';

  @override
  String get insightSleepAboveExpectedBody =>
      'O sono está acima do intervalo típico. Geralmente não é preocupante.';

  @override
  String get insightBedtimeVariabilityHighTitle => 'Horário de deitar variável';

  @override
  String insightBedtimeVariabilityHighBody(int minutes) {
    return 'O horário de deitar variou ±${minutes}min nos últimos dias.';
  }

  @override
  String get insightBedtimeVariabilityHighWhy =>
      'Consistência no horário pode ajudar a regular o sono.';

  @override
  String get insightBedtimeConsistencyGoodTitle => 'Boa consistência no deitar';

  @override
  String get insightBedtimeConsistencyGoodBody =>
      'O horário de deitar tem sido consistente. Continua assim!';

  @override
  String get insightNightFragmentationHighTitle => 'Noites fragmentadas';

  @override
  String get insightNightFragmentationHighBody =>
      'As noites têm tido vários despertares.';

  @override
  String insightNightFragmentationHighWhy(int count) {
    return 'Média de $count despertares por noite.';
  }

  @override
  String get insightLargestBlockImprovingTitle => 'Bloco noturno a melhorar';

  @override
  String get insightLargestBlockImprovingBody =>
      'O maior bloco de sono noturno está a aumentar.';

  @override
  String get insightTodayWasDifferentTitle => 'Hoje foi diferente';

  @override
  String get insightTodayWasDifferentBody =>
      'O sono de hoje diferiu significativamente da média recente.';

  @override
  String get insightAgeNorm0to3Title => 'Variabilidade é normal';

  @override
  String get insightAgeNorm0to3Body =>
      'Nos primeiros meses, é normal o sono variar muito de dia para dia.';

  @override
  String get insightAgeNorm4to12Title => 'Consolidação em curso';

  @override
  String get insightAgeNorm4to12Body =>
      'Nesta fase, o sono noturno começa a consolidar-se naturalmente.';

  @override
  String get insightAgeNorm12to24Title => 'Testar limites é normal';

  @override
  String get insightAgeNorm12to24Body =>
      'Resistir à hora de deitar é comum nesta idade. Mantém a calma!';

  @override
  String get insightSafeSleepBackToSleepTitle => 'Sono seguro: de costas';

  @override
  String get insightSafeSleepBackToSleepBody =>
      'Lembra: bebés devem dormir sempre de costas.';

  @override
  String get insightDayNightLowStimulusTitle => 'Estímulos baixos à noite';

  @override
  String get insightDayNightLowStimulusBody =>
      'Interações calmas e luz baixa à noite ajudam a estabelecer dia vs noite.';

  @override
  String get insightRoutineShortConsistentTitle => 'Rotina curta e consistente';

  @override
  String get insightRoutineShortConsistentBody =>
      'Uma rotina simples de 2–4 passos antes de dormir pode ajudar.';

  @override
  String get insightWhenCallPediatricianTitle => 'Quando contactar o pediatra';

  @override
  String get insightWhenCallPediatricianBody =>
      'Se algo te preocupa, não hesites em consultar o médico.';

  @override
  String get insightFewDataLearningTitle => 'Ainda a aprender';

  @override
  String get insightFewDataLearningBody =>
      'Precisamos de mais alguns dias de dados para gerar insights personalizados.';

  @override
  String get insightCtaLearnMore => 'Saber mais';

  @override
  String get insightCtaSave => 'Guardar';

  @override
  String get insightCtaCheckGuide => 'Ver guia';

  @override
  String get insightCtaOpenGuide => 'Abrir guia';

  @override
  String get insightCtaTryThis => 'Experimentar isto';

  @override
  String get insightCtaWhyThis => 'Porquê isto?';

  @override
  String get insightCtaDismiss => 'Dispensar';

  @override
  String get routineSuggestionTitle => 'Sugestão de rotina';

  @override
  String get routineNextNap => 'Próxima sesta';

  @override
  String routineNextNapWindow(String start, String end) {
    return 'Janela: $start–$end';
  }

  @override
  String routineNextNapSuggested(String time) {
    return 'Sugerido: $time';
  }

  @override
  String get routineBedtime => 'Hora de deitar';

  @override
  String routineBedtimeWindow(String start, String end) {
    return 'Janela: $start–$end';
  }

  @override
  String routineBedtimeSuggested(String time) {
    return 'Sugerido: $time';
  }

  @override
  String get routineNoData => 'Ainda sem dados suficientes para sugerir';

  @override
  String get routineCurrentlySleeping => 'A dormir — bom descanso!';

  @override
  String get routineNapWindowPassed => 'A janela de sesta já passou';

  @override
  String get routineExplanation => 'Baseado nos padrões recentes';

  @override
  String routineNapCount(int count) {
    return '$count sestas esperadas';
  }

  @override
  String routineNapDuration(int minutes) {
    return '~${minutes}min cada';
  }

  @override
  String get guide_normal_por_idade_title => 'O que é normal por idade';

  @override
  String get guide_normal_por_idade_subtitle =>
      'Expectativas de sono 0–24 meses';

  @override
  String get guide_dia_vs_noite_title => 'Dia vs Noite';

  @override
  String get guide_dia_vs_noite_subtitle => 'Como ajudar o ritmo circadiano';

  @override
  String get guide_rotina_antes_dormir_title => 'Rotina antes de dormir';

  @override
  String get guide_rotina_antes_dormir_subtitle => 'Passos simples para ajudar';

  @override
  String get guide_sono_seguro_title => 'Sono seguro';

  @override
  String get guide_sono_seguro_subtitle => 'Práticas recomendadas';

  @override
  String get guide_quando_pediatra_title => 'Quando falar com o pediatra';

  @override
  String get guide_quando_pediatra_subtitle => 'Sinais de atenção';

  @override
  String get guideOpenSection => 'Abrir';

  @override
  String get guideBackToList => 'Voltar';

  @override
  String get guideDisclaimer =>
      'Este conteúdo é informativo e não substitui aconselhamento médico personalizado.';

  @override
  String get cockpitTodayLabel => 'Today';

  @override
  String cockpitRecommended(String range) {
    return 'Recommended: $range';
  }

  @override
  String cockpitReference(String range) {
    return 'Reference: $range';
  }

  @override
  String get cockpitAddDobForGoal => 'Add birth date for age-based goals';

  @override
  String get cockpitAddDob => 'Add DOB';

  @override
  String get cockpitNoDataYet => 'When you record sleep, progress shows here.';

  @override
  String get cockpitBuildingTrend => 'Building trend with more records.';

  @override
  String get cockpitApproachingReference => 'Approaching reference zone.';

  @override
  String get cockpitApproachingMin => 'Heading to recommended minimum.';

  @override
  String get cockpitWithinReference => 'Within reference.';

  @override
  String get cockpitWithinRange => 'Within recommended range.';

  @override
  String get cockpitDifferentToday => 'Today was different — look at the week.';

  @override
  String get cockpitUpdatingWhileSleeping => 'Updating while sleeping.';

  @override
  String get cockpitInProgress => 'In progress';

  @override
  String get predictionTitle => 'Likely next sleep';

  @override
  String get predictionCollecting =>
      'Collecting pattern — record a few more sleeps.';

  @override
  String get predictionSleepingNow =>
      'Sleeping now — prediction available after waking.';

  @override
  String get predictionDataQualityLow =>
      'Review records to improve prediction.';

  @override
  String get predictionWindowPassed =>
      'Window has passed — today was atypical.';

  @override
  String predictionConfidence(String level) {
    return 'Confidence: $level';
  }

  @override
  String predictionBasedOn(int count) {
    return 'Based on last $count gaps between sleeps.';
  }

  @override
  String get predictionRemindMe => 'Remind me';

  @override
  String get predictionRemindMeSoon => 'Coming soon';

  @override
  String get predictionHowWeCalculate => 'How we calculate';

  @override
  String get predictionExplainTitle => 'How prediction works';

  @override
  String get predictionExplain1 => 'We look at recent gaps between sleeps.';

  @override
  String get predictionExplain2 =>
      'We use the median to reduce impact of atypical days.';

  @override
  String get predictionExplain3 =>
      'The window widens when there\'s more variability.';

  @override
  String get predictionDataPartial => 'Data: Partial';

  @override
  String get predictionDataIncomplete => 'Data: Incomplete';

  @override
  String get predictionSeeDetails => 'See details';

  @override
  String get dataQualityTitle => 'Data quality';

  @override
  String get dataQualityGood => 'Good';

  @override
  String get dataQualityPartial => 'Partial';

  @override
  String get dataQualityIncomplete => 'Incomplete';

  @override
  String get dataQualityWarning => 'Prediction may be less accurate today.';

  @override
  String get dataQualitySeeDetails => 'See details';

  @override
  String get timelineTitle => 'Today';

  @override
  String get timelineSeeAll => 'See all';

  @override
  String get timelineSeeMore => 'See more';

  @override
  String get timelineNoRecords => 'No records today yet';

  @override
  String get timelineAddManual => 'Add manual';

  @override
  String get quickActionsAddManual => 'Add manual';

  @override
  String get quickActionsEditLast => 'Edit last';

  @override
  String get quickActionsViewDay => 'View day';
}
