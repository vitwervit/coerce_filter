# RPC Coercion Filter

Блокировка RPC-интерфейсов, используемых в атаках coerced authentication (NTLM Relay).

> ⚠️ **ВАЖНО: Печать через Print Spooler (MS-RPRN) перестанет работать на хостах где применён фильтр.**
> Если в инфраструктуре используются принтеры через DC — перед применением отключите службу Spooler
> на контроллерах домена и перенесите печать на отдельный print-сервер, не являющийся DC.

---

## Покрытые векторы

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

## Влияние на инфраструктуру

| Функциональность | Результат после применения |
|------------------|---------------------------|
| Печать через DC (Print Spooler) | ❌ Не работает |
| Печать через отдельный print-сервер (не DC) | ✅ Работает |
| Доменная аутентификация | ✅ Не затронута |
| Групповые политики | ✅ Не затронуты |
| Репликация между DC | ✅ Не затронута |
| DFS (доступ к файлам, `\\domain\share`) | ✅ Работает — MS-DFSC идёт через SMB, не RPC |
| DFS администрирование (`dfsmgmt.msc`, PowerShell) | ❌ Не работает — MS-DFSNM заблокирован |
| EFS (шифрование файлов) | ⚠️ Проверить — MS-EFSR заблокирован |
| Теневые копии VSS | ⚠️ Проверить — MS-FSRVP заблокирован |

### Рекомендация по печати

Перед применением фильтра на DC:

```cmd
:: Отключить Print Spooler на контроллерах домена
sc config spooler start= disabled
net stop spooler
```

Печать должна работать через выделенный print-сервер, не являющийся DC.
Это правильная практика вне зависимости от данного фильтра.

---

## Персистентность

RPC-фильтры **сбрасываются при перезагрузке**. Для постоянного применения необходимо
настроить автоматический запуск через GPO + Scheduled Task (см. раздел «Деплой»).

---

## Деплой на все компьютеры домена

Рекомендуемый способ: **GPO + Scheduled Task**.
GPO доставляет скрипт на хост, Scheduled Task обеспечивает запуск при каждом старте от SYSTEM,
до входа любого пользователя.

### Шаг 1 — Разместить скрипт в SYSVOL

```
\\corp.local\SYSVOL\corp.local\scripts\rpc_coerce_filter.cmd
```

### Шаг 2 — Создать GPO

1. Открыть `gpmc.msc`
2. Правой кнопкой на нужный OU (или весь домен) → **Create a GPO and Link it here**
3. Назвать: `RPC Coercion Filter`

### Шаг 3 — GPO: скопировать скрипт на хост

`Computer Configuration → Preferences → Windows Settings → Files`

| Поле | Значение |
|------|----------|
| Action | Replace |
| Source | `\\corp.local\SYSVOL\corp.local\scripts\rpc_coerce_filter.cmd` |
| Destination | `C:\Windows\System32\rpc_coerce_filter.cmd` |

### Шаг 4 — GPO: создать Scheduled Task (персистентность)

`Computer Configuration → Preferences → Control Panel Settings → Scheduled Tasks`
`→ New → Scheduled Task (At least Windows 7)`

| Поле | Значение |
|------|----------|
| Action | Replace |
| Name | RPC Coercion Filter |
| Run As | SYSTEM |
| Run with highest privileges | ✅ |
| Trigger | At startup |
| Execute | `netsh.exe` |
| Arguments | `-f C:\Windows\System32\rpc_coerce_filter.cmd` |
| Stop task if runs longer than | 5 minutes |

### Шаг 5 — GPO: Immediate Task (применить без перезагрузки)

`Scheduled Tasks → New → Immediate Task (At least Windows 7)`

Те же настройки, триггер **Once** с датой в прошлом —
выполнится сразу при следующем применении GPO на хосте.

### Шаг 6 — Принудительное применение GPO

```powershell
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name

Invoke-Command -ComputerName $computers -ScriptBlock {
    gpupdate /force
} -ErrorAction SilentlyContinue
```

---

## Проверка применения

### На одной машине

```cmd
netsh rpc filter show filter
```

Должно быть 9 правил с `actiontype = block`.

### На всех машинах домена

```powershell
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name

Invoke-Command -ComputerName $computers -ScriptBlock {
    $task = Get-ScheduledTask -TaskName "RPC Coercion Filter" -ErrorAction SilentlyContinue
    $filters = (netsh rpc filter show filter 2>&1 | Select-String "actiontype\s*=\s*block").Count
    [PSCustomObject]@{
        Computer    = $env:COMPUTERNAME
        TaskExists  = ($null -ne $task)
        TaskState   = if ($task) { $task.State } else { "Missing" }
        FilterCount = $filters
        Status      = if ($filters -eq 9) { "OK" } else { "MISSING" }
    }
} -ErrorAction SilentlyContinue | Sort-Object Status | Format-Table -AutoSize
```

---

## Удаление фильтров

### На одной машине

```cmd
netsh rpc filter
delete filter filterkey=all
quit
```

### На всех машинах домена

```powershell
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name

Invoke-Command -ComputerName $computers -ScriptBlock {
    netsh rpc filter
    delete filter filterkey=all
    quit
} -ErrorAction SilentlyContinue
```

### Удалить Scheduled Task

```powershell
Invoke-Command -ComputerName $computers -ScriptBlock {
    Unregister-ScheduledTask -TaskName "RPC Coercion Filter" -Confirm:$false -ErrorAction SilentlyContinue
} -ErrorAction SilentlyContinue
```



