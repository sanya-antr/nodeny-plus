package lang;
my $br  = '<br>';
my $br2 = '<br><br>';

# Конвертирование символов при неверной раскладке клавиатуры
%keyboard_convert = (
    from => 'qwertyuiop[]asdfghjkl;zxcvbnm,.QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>&\'',
    to   => 'йцукенгшщзхъфывапролджячсмитьбюЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ э',
);

%tanslit = (
  'а'=>'a', 'б'=>'b', 'в'=>'v', 'г'=>'g', 'д'=>'d', 'е'=>'e', 'ё'=>'yo', 'ж'=>'zh', 'з'=>'z', 'и'=>'i',
  'й'=>'y', 'к'=>'k', 'л'=>'l', 'м'=>'m', 'н'=>'n', 'о'=>'o', 'п'=>'p',  'р'=>'r',  'с'=>'s', 'т'=>'t',
  'у'=>'u', 'ф'=>'f', 'х'=>'h', 'ц'=>'c', 'ч'=>'ch','ш'=>'sh','щ'=>'sh', 'ъ'=>'j',  'ы'=>'i', 'ь'=>'j',
  'э'=>'e', 'ю'=>'yu','я'=>'ya',
  'А'=>'A', 'Б'=>'B', 'В'=>'V', 'Г'=>'G', 'Д'=>'D', 'Е'=>'E', 'Ё'=>'YO', 'Ж'=>'ZH', 'З'=>'Z', 'И'=>'I',
  'Й'=>'Y', 'К'=>'K', 'Л'=>'L', 'М'=>'M', 'Н'=>'N', 'О'=>'O', 'П'=>'P',  'Р'=>'R',  'С'=>'S', 'Т'=>'T',
  'У'=>'U', 'Ф'=>'F', 'Х'=>'H', 'Ц'=>'C', 'Ч'=>'CH','Ш'=>'SH','Щ'=>'SH', 'Ъ'=>'J',  'Ы'=>'I', 'Ь'=>'J',
  'Э'=>'E', 'Ю'=>'YU','Я'=>'YA',
);

# По колонкам:
# 0: приставка гига/мега/кило
# 1: B - byte, b - bit
# 2: если установлен, то 3 знака после запятой, иначе как целое число
# 3: если установлен, то за секунду
@Ed = (
    [ 'G','B',1,0,   'Гб,' ],
    [ 'G','B',0,0,   'Гб'  ],
    [ 'M','B',1,0,   'Мб,' ],
    [ 'M','B',0,0,   'Мб'  ],
    [ 'K','B',1,0,   'Кб,' ],
    [ 'K','B',0,0,   'Кб'  ],
    [ ' ','B',0,0,   'Байт'],
    [ 'K','B',1,1,   'Кбайт/сек' ],
    [ 'K','b',1,1,   'Кбит/сек'  ],
    [ 'M','b',1,1,   'Мбит/сек'  ],
);

@month_names            = ('','январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь');
@month_names_for_day    = ('','января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря');
#@Lang_month_names_for_day = ('','січня','лютого','березня','квiтня','травня','червня','липня','серпня','вересня','жовтня','листопада','грудня');

# Значения поля cstate таблицы users
%cstates = (
  0  => 'Все OK',
  1  => 'На подключении',
  2  => 'Читай комментарии',
  3  => 'Требуется ремонт',
  4  => 'Заявка на ремонт',
  5  => 'В ремонте',
  6  => 'Настроить',
  7  => 'Отключен физически',
  8  => 'Отключить физически',
  9  => 'Отключить немедленно',
  10 => 'Отказ от подключения',
  11 => 'Вирусы',
  12 => 'Потери',
  13 => 'Перерасчет',
);

%dopfield_types = (
  0  => 'целое',
  1  => 'целое положительное',
  2  => 'вещественное',
  3  => 'вещественное положительное',
  4  => 'строковое однострочное',
  5  => 'строковое многострочное',
  6  => 'да/нет',
  8  => 'выпадающий список',
  9  => 'пароль',
  10 => 'трафик',
  11 => 'время',
  13 => 'деньги',
);

# Оплачиваемая составляющая трафика
$directions = {
    0 => ['входящий', 'Вход', 'вход'],
    1 => ['исходящий', 'Исход', 'исход'],
    2 => ['вход+выход', 'Сумма', 'сумма'],
    3 => ['наибольшая составляющая', 'Большее', 'большее'],
};

$card_alives = {
    'good'      => 'не активирована',
    'bad'       => 'заблокирована',
    'stock'     => 'на складе',
    'activated' => 'активирована',
};

$fullusers_fields_name = {
    fio         => 'ФИО',
    name        => 'Логин',
    contract    => 'Договор',
    comment     => 'Комментарий',
    final_balance => 'Остаток',
    submoney    => 'Сумма снятия',
    balance     => 'Баланс',
    traf        => 'Трафик, Мб',
    traf_out    => 'Исх. трафик, Мб',
    traf_in     => 'Вх. трафик, Мб',
};

$msg_after_submit   = 'Ждите...';

$err_no_priv        = 'Недостаточно привилегий.';
$err_untrusted_ses  = 'Не разрешен доступ, поскольку вы работаете в безопасном режиме. Перелогиньтесь';
$err_try_again      = 'Произошла временная ошибка. Попробуйте повторить запрос.';
$cannot_load_file   = 'Не могу загрузить файл []';

$yes    = 'Да';
$no     = 'Нет';
$on     = 'Вкл';
$off    = 'Выкл';

$help               = 'Справка';
$today              = 'сегодня';
$hidden             = 'скрыто';

$lbl_mb             = 'Мб';
$lbl_login          = 'Логин';
$lbl_pass           = 'Пароль';
$lbl_fio            = 'ФИО';
$lbl_phone          = 'Телефон';
$lbl_inet_access    = 'Доступ';
$lbl_inet_auth      = 'Авторизация';
$lbl_block_if_limit = 'Блокировать при лимите';
$lbl_usr_cstate     = 'Состояние';

$lbl_default_name_traf = '№';
$lbl_traf           = 'трафик';
$lbl_traf_to_user   = 'к клиенту';
$lbl_traf_from_user = 'от клиента';
$lbl_traf_for_pay   = 'оплачиваемый';

$lbl_time           = 'Время';
$lbl_author         = 'Автор';
$lbl_msg            = 'Сообщение';
$lbl_bonus          = 'Бонус';
$lbl_amt            = 'Сумма';

# Кнопки
$btn_enter              = '&nbsp;&nbsp;Вход&nbsp;&nbsp;';
$btn_logout             = 'Выход';
$btn_go_next            = 'Далее';
$btn_save               = 'Сохранить';
$btn_cancel             = 'Отменить';
$btn_delete             = 'Удалить';

$adm_is_not_exist       = 'несуществующий админ id = [filtr]';

$chkbox_list_all        = 'Все';
$chkbox_list_invert     = 'Инверсия';

# --- login.pl ---

$mLogin_login       = 'Логин';
$mLogin_pass        = 'Пароль';

# --- title.pl ---

$mTitle_hello_adm       = 'Здравствуйте, [filtr]';
$mTitle_dont_remind     = 'Не напоминать';

# --- tune.pl ---

$section_is             = 'Раздел: [bold]';

# --- users.pl ---

$mUsers_search_modes = [
    0 => 'начинается с',
    1 => 'имеет фрагмент',
    2 => '=',
    3 => 'не =',
    4 => '>',
    5 => '<',
    6 => 'не начинается с',
    7 => 'пустое поле',
];

# Расшифровка в каких таблицах производится поиск
$mUsers_search_tbl = {
    u => 'основные данные',
    d => 'дополнительные данные',
    i => '',
    s => '',
};

$mUser_new_ask          = 'Создать учетную запись клиента в группе [] [p h_center]';

# --- user.pl ---

$mUser_err_get_data     = 'Ошибка получения данных клиента';
$mUser_err_grp_access   = 'Запрашиваемая запись принадлежит группе, доступ к которой вам запрещен.';
$mUser_err_no_grp_access = 'Нет доступа ни к одной группе клиентов';
@mUser_auth_header      = ('Ip','Старт','Длительность','Модуль авторизации');
@mUser_traf_header      = ('Направление','к клиенту','от клиента');


# --- Data.pm ---

$mData_pass_hard        = 'сложный пароль';
$mData_pass_good        = 'без символов 1,l,I,0,O';
$mData_pass_num         = 'только из чисел';
$mData_pass_short       = 'короткий';


# --- traf.pl ---

@mTraf_tbl_head         = ('', 'Входящий', 'Исходящий', '');
@mTraf_tbl_head_detail  = ('', 'Ip клиента', '', 'Удаленный ip', 'Порт', 'Прот.', 'Трафик', 'Направление');

@mTraf_log_tbl_head     = ('', 'Время', 'Входящий', 'Исходящий', 'График скорости');

# --- yamap.pl ---

$mYamap_add_to_map          = 'Добавить на карту';
$mYamap_create_usr_mark     = 'клиента';
$mYamap_create_place_mark   = 'место';


# --- operations.pl ---

$cards_move_intro = <<MSG;
    <p>Выберите администратора, которому собираетесь передать карточки пополнения счета.</p>
MSG

$cards_move_err_office  = "Передача карточек не выполнена т.к. администратор, которому вы передаете карточки, работает в другом отделе. ".
                          "<p>У вас нет доступа к другим отделам.</p>";
$cards_move_err_adm_id  = "Передача карточек не выполнена т.к. указан неверный id администратора на которого была запрошена передача.";
$cards_move_err_priv1   = "Передача карточек не выполнена т.к. администратор, которому вы передаете карточки, не имеет прав на их прием.";


# === Клиентская статистика ===

$s_critical_error           = 'Ведутся технические работы. Заходите позже.';
$s_soft_error               = 'Временная ошибка. Попробуйте повторить запрос.';
$s_temporarily_unavailable  = 'Данный раздел временно недоступен';

$s_no_usr_selected          = 'Не выбран клиент';
$s_title                    = 'Страница статистики';

# Для администратора

$s_adm_detail_msg           = '<p>Вы администратор, поэтому вам видны более детальные описания ошибок:</p>';
$s_err_no_stat_priv         = 'Вашей административной записи не разрешено просматривать статистику клиентов.';
$s_err_no_u_grp_priv        = 'Вам не разрешено просматривать статистику записей в этой группе.';
$s_err_tmp_err              = 'Вероятно временная ошибка. Если вы суперадмин, смотри debug';


# --- user/main.pl ---

$sMain_cur_debt             = 'текущий долг: []';
$sMain_cur_balance          = 'текущий остаток на счете: []';
$sMain_request_info         = 'Для работы в сети, вам необходимо указать следующие данные';
$sMain_your_service         = '[] подключена услуга [filtr|bold|commas]'; # [время] [имя услуги]
$smain_err_pkt              = 'ошибочный тариф (сообщите администратору)';
$smain_msg_from_adm         = '[] сообщение от администрации[div small_msg]'; # [время] [сообщение]
$smain_tmp_pay              = '<p>Обратите внимание: чтобы не блокировать доступ несмотря на вашу задолженность, '.
            'администрация оформила временный платеж в размере [bold] []</p>'.
            '<p>Через определенное время он удалится автоматически, поэтому если вы еще не погасили задолженность - '.
            'рекомендуем это сделать до [bold].</p><p>[]</p>';
                                # сумма, валюта, время, ссылка на раздел платежей
$smain_see_pays             = 'См. ваши платежи';
$smain_accepted_msg         = 'Благодарим за то, что ознакомились с сообщением администрации';
$smain_btn_paymod           = 'Платежи';
$smain_day_to_block         = 'До блокировки доступа по финансовым причинам осталось [bold] дней';
$smain_wait_block           = 'В ближайшее время доступ будет заблокирован по финансовым причинам';
$sMain_msg_accepted         = 'Ознакомлен';
$smain_negative_pay         = '[] со счета снято [bold] []';
$smain_positive_pay         = '[] счет пополнен на [bold] []';
$smain_btn_more             = 'Подробнее';
$smain_lbl_login            = 'Логин';
$smain_lbl_access           = 'Доступ';
$sMain_balance_is           = 'Остаток на счете';
$smain_credit_is            = 'Возможный кредит';
$sMain_private_data         = 'Личные данные';
$smain_your_PPC_is          = 'Ваш персональный платежный код: [b]';

# --- user/messadm.pl ---

# Для администратора
$smsadm_btn_more            = 'Детальнее'; # показать детали сообщения

# Для клиента
$smsadm_msg_to_adm          = "<p class='data2 big'>Отправить сообщение администрации:</p>";
$smsadm_1_msg               = 'одно ваше сообщение';
$smsadm_2_msg               = 'два ваших сообщения';
$smsadm_3_msg               = '3 ваших сообщения';
$smsadm_4_msg               = '4 ваших сообщения';
$smsadm_x_msg               = 'ваших сообщений';
$smsadm_sent_count          = 'Администрация пока не дала ответ на []. Ожидайте';
$smsadm_send                = 'Отправить';
$smsadm_your_msg_quote      = 'На ваше сообщение:[filtr|div small_msg]Отвечаем:[br2]';
$smsadm_from_adm            = 'От администрации';
$smsadm_from_u              = 'Ваше сообщение';
$smsadm_msg_not_allowed     = 'Отправка сообщений заблокирована администрацией.[br][bold]';
$smsadm_n_msg_allowed       = 'Разрешается отсылать не более [] сообщений в сутки, на которые не был дан ответ. Подождите некоторое время - мы отреагируем на ваши вопросы и вы сможете задать новые';
$smsadm_long_mess_1         = 'Сообщение слишком длинное';
$smsadm_long_mess_2         = 'Постарайтесь сформулировать мысль короче. Уменьшить объем сообщения помогает удаление серий из вопросительных и восклицательных знаков.';
$smsadm_sent                = 'Сообщение отправлено администрации.';
$smsadm_btn_go_next         = 'Далее';

$smsadm_email_tmpl          =<<MSG;
    Здравствуйте, администратор биллинговой системы NoDeny.

    Это сообщение отправлено через веб-форму со страницы статистики клиента
    --- Сообщение ---------------------------------------------------------
    []
    -----------------------------------------------------------------------
    
    Ответить клиенту можете по ссылке: []
    Данные клиента: []
MSG


# --- user/cards.pl ---

$sCards_totop               = 'Пополнение счета скретч-картами';
$scards_intro = <<MSG;
    <div class='align_center'>
        <div class='txtpadding'>Введите код активации, указанный на карточке пополнения счета:</div>
    </div>
    <div class='align_center'>
        <div class='txtpadding'>{{input}}</div>
    </div>
MSG
$sCards_many_errs           = 'Слишком много неверно введенных кодов пополнения.<p>Разрешение на пополнение будет выдано через время</p>';
$sCards_err_cod             = "Ошибка: код пополнения неверен!";
$sCards_expired             = "Карта [bold] не может быть активирована - срок ее действия закончился";
$scards_already_activated   = "Карта [bold] уже активирована другим клиентом.<p>Не выкидывайте карту и обратитесь к администрации</p>";
$scards_already_activated2  = "Карта [bold] уже активирована вами.<p>Смотрите свои платежи</p>";
$scards_err_state           = "Карта [bold] не подлежит активации.<p>Не выкидывайте карту и обратитесь к администрации</p>";
$scards_finish_ok           = "Ваш счет пополнен на [] $cfg::gr картой пополнения счета []";

# --- user/auth_log.pl ---

$sAuth_log_totop            = 'Сеансы подключений';
@sAuth_tbl_head             = ('Старт', 'Завершение', 'Длительность', 'ip');


@sPays_tbl_head             = ('Время', "+ $cfg::gr", "- $cfg::gr", "Остаток, $cfg::gr", 'Комментарий');




















1;