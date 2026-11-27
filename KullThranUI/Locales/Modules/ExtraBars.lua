-- Resource Bars (Extra Mana Bar) and Experience Bar (second bar) options, for every
-- supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Extra Mana Bar",
    "Extra Mana Bar Height",
    "Shows your mana on its own bar above the power bar while your resource is another one, such as Energy or Rage in a druid form.",
    "A reputation or honor bar with the same look as the main bar. Reputation shows the faction marked to show as an experience bar. It is hidden while the main bar shows the same thing.",
    "Second Bar",
    "Show Second Bar",
    "Second Bar Mode",
    "Second Bar Position",
    "Detach from Stack",
    "Detach Extra Mana Bar",
    "Bars detached from the stack move on their own in Unlock Mode. Until you move one, it keeps its place in the stack.",
    "Autoattack Bar Style",
}

local values = {
    esES = {
        "Barra de maná extra",
        "Altura de la barra de maná extra",
        "Muestra tu maná en su propia barra encima de la barra de poder mientras tu recurso es otro, como la Energía o la Ira en una forma de druida.",
        "Una barra de reputación o de honor con el mismo aspecto que la barra principal. La reputación muestra la facción marcada para mostrarse como barra de experiencia. Se oculta mientras la barra principal muestra lo mismo.",
        "Segunda barra",
        "Mostrar segunda barra",
        "Modo de la segunda barra",
        "Posición de la segunda barra",
        "Separar de la pila",
        "Separar la barra de maná extra",
        "Las barras separadas de la pila se mueven por su cuenta en el modo de desbloqueo. Hasta que muevas una, se queda en su sitio de la pila.",
        "Estilo de las barras de autoataque",
    },
    deDE = {
        "Zusätzliche Manaleiste",
        "Höhe der zusätzlichen Manaleiste",
        "Zeigt dein Mana in einer eigenen Leiste über der Energieleiste, solange deine Ressource eine andere ist, etwa Energie oder Wut in einer Druidengestalt.",
        "Eine Ruf- oder Ehreleiste im selben Aussehen wie die Hauptleiste. Ruf zeigt die Fraktion, die als Erfahrungsleiste angezeigt werden soll. Sie wird ausgeblendet, solange die Hauptleiste dasselbe zeigt.",
        "Zweite Leiste",
        "Zweite Leiste anzeigen",
        "Modus der zweiten Leiste",
        "Position der zweiten Leiste",
        "Vom Stapel lösen",
        "Zusätzliche Manaleiste lösen",
        "Vom Stapel gelöste Leisten bewegst du im Entsperrmodus einzeln. Bis du eine verschiebst, behält sie ihren Platz im Stapel.",
        "Stil der Automatischen-Angriff-Leisten",
    },
    frFR = {
        "Barre de mana supplémentaire",
        "Hauteur de la barre de mana supplémentaire",
        "Affiche votre mana dans sa propre barre au-dessus de la barre de puissance tant que votre ressource est une autre, comme l’énergie ou la rage sous une forme de druide.",
        "Une barre de réputation ou d’honneur avec le même aspect que la barre principale. La réputation affiche la faction marquée pour s’afficher comme barre d’expérience. Elle est masquée tant que la barre principale affiche la même chose.",
        "Deuxième barre",
        "Afficher la deuxième barre",
        "Mode de la deuxième barre",
        "Position de la deuxième barre",
        "Détacher de la pile",
        "Détacher la barre de mana supplémentaire",
        "Les barres détachées de la pile se déplacent seules en mode déverrouillage. Tant que vous n'en déplacez pas une, elle garde sa place dans la pile.",
        "Style des barres d'attaque automatique",
    },
    itIT = {
        "Barra del mana aggiuntiva",
        "Altezza della barra del mana aggiuntiva",
        "Mostra il mana in una barra a parte sopra la barra del potere finché la tua risorsa è un’altra, come l’energia o l’ira in una forma da druido.",
        "Una barra della reputazione o dell’onore con lo stesso aspetto della barra principale. La reputazione mostra la fazione indicata da mostrare come barra dell’esperienza. Viene nascosta finché la barra principale mostra la stessa cosa.",
        "Seconda barra",
        "Mostra seconda barra",
        "Modalità della seconda barra",
        "Posizione della seconda barra",
        "Stacca dalla pila",
        "Stacca la barra del mana extra",
        "Le barre staccate dalla pila si spostano da sole in modalità sblocco. Finché non ne sposti una, resta al suo posto nella pila.",
        "Stile delle barre dell'attacco automatico",
    },
    ptBR = {
        "Barra de mana extra",
        "Altura da barra de mana extra",
        "Mostra sua mana em uma barra própria acima da barra de poder enquanto seu recurso for outro, como Energia ou Raiva em uma forma de druida.",
        "Uma barra de reputação ou de honra com a mesma aparência da barra principal. A reputação mostra a facção marcada para aparecer como barra de experiência. Ela fica oculta enquanto a barra principal mostra o mesmo.",
        "Segunda barra",
        "Mostrar segunda barra",
        "Modo da segunda barra",
        "Posição da segunda barra",
        "Separar da pilha",
        "Separar a barra de mana extra",
        "Barras separadas da pilha se movem sozinhas no modo de desbloqueio. Até você mover uma, ela fica no seu lugar na pilha.",
        "Estilo das barras de ataque automático",
    },
    ruRU = {
        "Дополнительная полоса маны",
        "Высота дополнительной полосы маны",
        "Показывает ману на отдельной полосе над полосой ресурса, пока ваш ресурс другой, например энергия или ярость в облике друида.",
        "Полоса репутации или чести того же вида, что и основная полоса. Репутация показывает фракцию, отмеченную для показа на полосе опыта. Скрывается, пока основная полоса показывает то же самое.",
        "Вторая полоса",
        "Показывать вторую полосу",
        "Режим второй полосы",
        "Положение второй полосы",
        "Отделить от стопки",
        "Отделить дополнительную полосу маны",
        "Отделённые от стопки полосы перемещаются по отдельности в режиме разблокировки. Пока вы не переместите полосу, она остаётся на своём месте в стопке.",
        "Стиль полос автоатаки",
    },
    koKR = {
        "추가 마나 바",
        "추가 마나 바 높이",
        "주 자원이 마나가 아닐 때(예: 드루이드 변신 중 기력이나 분노) 자원 바 위에 마나를 별도의 바로 표시합니다.",
        "주 바와 같은 모양의 평판 또는 명예 바입니다. 평판은 경험치 바로 표시하도록 지정한 진영을 보여 줍니다. 주 바가 같은 내용을 표시하는 동안에는 숨겨집니다.",
        "두 번째 바",
        "두 번째 바 표시",
        "두 번째 바 모드",
        "두 번째 바 위치",
        "묶음에서 분리",
        "추가 마나 바 분리",
        "묶음에서 분리한 바는 잠금 해제 모드에서 따로 움직입니다. 옮기기 전까지는 묶음 안의 자리에 그대로 있습니다.",
        "자동 공격 바 스타일",
    },
    zhCN = {
        "额外法力条",
        "额外法力条高度",
        "当你的主要资源不是法力值时（例如德鲁伊形态下的能量或怒气），在能量条上方单独显示法力值。",
        "与主条外观相同的声望或荣誉条。声望显示被设为以经验条显示的阵营。当主条显示相同内容时会隐藏。",
        "第二条",
        "显示第二条",
        "第二条模式",
        "第二条位置",
        "从堆叠中分离",
        "分离额外法力条",
        "从堆叠中分离的条可以在解锁模式中单独移动。在你移动之前，它会留在堆叠中的原位。",
        "自动攻击条样式",
    },
    zhTW = {
        "額外法力條",
        "額外法力條高度",
        "當你的主要資源不是法力時（例如德魯伊形態下的能量或怒氣），在能量條上方單獨顯示法力。",
        "與主條外觀相同的聲望或榮譽條。聲望顯示被設為以經驗條顯示的陣營。當主條顯示相同內容時會隱藏。",
        "第二條",
        "顯示第二條",
        "第二條模式",
        "第二條位置",
        "從堆疊中分離",
        "分離額外法力條",
        "從堆疊中分離的條可以在解鎖模式中單獨移動。在你移動之前，它會留在堆疊中的原位。",
        "自動攻擊條樣式",
    },
}

local function Apply(target, locale)
    if type(target) ~= "table" then return end
    local translated = values[locale]
    for index, key in ipairs(keys) do
        if target[key] == nil or target[key] == key then
            target[key] = translated and translated[index] or key
        end
    end
end

for _, locale in ipairs({ "enUS", "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    Apply(locales[locale], locale)
end
if locales.esMX and locales.esMX ~= locales.esES then Apply(locales.esMX, "esES") end
if locales.ptPT and locales.ptPT ~= locales.ptBR then Apply(locales.ptPT, "ptBR") end
