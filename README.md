# RPC Coercion Filter

Набор RPC-фильтров, который закрывает интерфейсы, через которые проводят coerced authentication (NTLM Relay): PrinterBug, PetitPotam, DFSCoerce и родственные атаки. Фильтры ставятся через `netsh rpc filter` и блокируют вызовы к нужным UUID.



---

## Что блокируется

| Атака           | Протокол  | UUID                                   |
|-----------------|-----------|----------------------------------------|
| PrinterBug      | MS-RPRN   | `12345678-1234-ABCD-EF00-0123456789AB` |
| PrinterBug      | MS-RPRN   | `c681d488-d850-11d0-8c52-00c04fd90f7e` |
| AsyncPrintBug   | MS-PAR    | `76f03f96-cdfd-44fc-a22c-64950a001209` |
| PetitPotam      | MS-EFSR   | `df1941c5-fe89-4e79-bf10-463657acf44d` |
| PetitPotam      | MS-EFSR   | `c8cb7687-e6d3-11d2-a958-00c04f682e16` |
| DFSCoerce       | MS-DFSNM  | `4fc742e0-4a10-11cf-8273-00aa004ae673` |
| ShadowCoerce    | MS-FSRVP  | `a8e0653c-2744-4389-a61d-7373df8b2292` |
| EventLog coerce | MS-EVEN   | `82273fdc-e32a-18c3-3f78-827929dc23ea` |
| EventLog coerce | MS-EVEN6  | `f6beaff7-1e19-4fbb-9f8f-b89e2018337c` |

---

## Что сломается, а что нет

| Функциональность | После применения |
|------------------|------------------|
| Печать через DC (Print Spooler) | Не работает |
| DFS-администрирование (`dfsmgmt.msc`, PowerShell) | Не работает: MS-DFSNM заблокирован |
| EFS (шифрование файлов) | Проверьте у себя: MS-EFSR заблокирован |
| Теневые копии VSS | Проверьте у себя: MS-FSRVP заблокирован |



### Про печать

Перед тем как применять фильтр на DC, отключите Spooler:

```cmd
:: Отключить Print Spooler на контроллерах домена
sc config spooler start= disabled
net stop spooler
```

Печатать нужно через выделенный print-сервер, который не является DC. Так стоит делать и без этого фильтра: Spooler на контроллере домена давно считается плохой идеей.

---

## Фильтры не переживают перезагрузку

RPC-фильтры, добавленные через `netsh`, после рестарта пропадают. Поэтому одного запуска скрипта мало. Нужно, чтобы он выполнялся при каждом старте хоста. Для этого ниже связка GPO и Scheduled Task.

---

## Раскатка на домен

GPO кладёт скрипт на хост, а Scheduled Task запускает его при каждой загрузке от SYSTEM, ещё до входа любого пользователя.

### 1. Положите скрипт в SYSVOL

```
\\corp.local\SYSVOL\corp.local\scripts\rpc_coerce_filter.cmd
```

Домен `corp.local` здесь для примера, подставьте свой.

### 2. Создайте GPO

1. Откройте `gpmc.msc`.
2. Правой кнопкой на нужный OU (или на весь домен) → **Create a GPO and Link it here**.
3. Назовите его `RPC Coercion Filter`.

### 3. Скопируйте скрипт на хосты

`Computer Configuration → Preferences → Windows Settings → Files`

| Поле | Значение |
|------|----------|
| Action | Replace |
| Source | `\\corp.local\SYSVOL\corp.local\scripts\rpc_coerce_filter.cmd` |
| Destination | `C:\Windows\System32\rpc_coerce_filter.cmd` |

### 4. Создайте Scheduled Task

`Computer Configuration → Preferences → Control Panel Settings → Scheduled Tasks → New → Scheduled Task (At least Windows 7)`

| Поле | Значение |
|------|----------|
| Action | Replace |
| Name | RPC Coercion Filter |
| Run As | SYSTEM |
| Run with highest privileges | включить |
| Trigger | At startup |
| Execute | `netsh.exe` |
| Arguments | `-f C:\Windows\System32\rpc_coerce_filter.cmd` |
| Stop task if runs longer than | 5 minutes |

### 5. Добавьте Immediate Task

Без неё фильтры появятся только после перезагрузки. Чтобы они встали сразу, создайте ещё `Scheduled Tasks → New → Immediate Task (At least Windows 7)`.

Настройки те же, триггер **Once** с датой в прошлом. Задача выполнится, как только хост применит GPO.

### 6. Примените GPO принудительно

```powershell
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name

Invoke-Command -ComputerName $computers -ScriptBlock {
    gpupdate /force
} -ErrorAction SilentlyContinue
```

---

## Как проверить, что всё встало


```cmd
netsh rpc filter show filter
```

Должно быть N правил с `actiontype = block`.



---

## Как всё откатить


```cmd
netsh rpc filter
delete filter filterkey=all
quit
```


