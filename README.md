# RamisScript Compiler (RSMC) v0.8.0

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Linux x86--64](https://img.shields.io/badge/Platform-Linux%20x86--64-orange.svg)]()
[![Architecture: Zero--Libc AMD64](https://img.shields.io/badge/Architecture-Zero--Libc%20AMD64-red.svg)]()
[![Release: v0.8.0](https://img.shields.io/badge/Release-v0.8.0%20(September%202026)-green.svg)]()

[English](#english) | [Русский](#русский)

---

<a name="english"></a>
# English Documentation

**RamisScript (RSMC)** is a bare-metal, zero-overhead systems programming language and standalone native compiler written from scratch in pure x86-64 assembly (FASM) by Valeriy Kravchenko (KV/RaMIS Project Group).

The compiler operates with **zero libc, zero CRT0, and zero external dependencies**. It emits raw AMD64 machine code directly from AST passes into:
* Standalone native **ELF64** executables for Linux with direct `syscall` dispatching.
* In-memory executable pages for instant **JIT** compilation and execution via `sys_mmap`.
* Portable binary bytecode containers (**RSE** - RamisScript Executable).
* Raw 16KB bootable **MBR disk images** transitioning the CPU into 64-bit Long Mode.

---

## 1. What's New in v0.8.0 (Changelog vs v0.7.0)

| Component / Feature | Status in v0.7.0 | Implemented in v0.8.0 | Technical Description |
|---|:---:|:---:|---|
| **Networking Stack (`mode "net"`)** | ❌ None | ✅ Complete | Full TCP L4 socket support: `net.listen` (with `SO_REUSEADDR`), `net.accept`, `net.send`, `net.recv`, `net.close`. |
| **Zero-Copy Kernel `sendfile`** | ❌ None | ✅ Complete | Direct Linux kernel `sys_sendfile` pipe from page cache to socket descriptor without userspace memory roundtrip. |
| **Bare-Metal MBR Generator (`-img`)** | ❌ None | ✅ Complete | Compiles 16KB raw disk images with valid MBR signature (`0xAA55`), Real Mode to Protected Mode switch, identity paging, and 64-bit Long Mode jump. |
| **JIT Ring 0 Protection Trap** | ⚠️ SIGSEGV crash | ✅ Sandboxed | Automatic detection and interception of privileged Ring 0 instructions in JIT mode with graceful diagnostics. |
| **Terminal Raw Mode Support** | ❌ Canonical only | ✅ Complete | Direct `ioctl(0, TCGETS/TCSETS)` control: non-blocking input (`VMIN=0, VTIME=0`), disabled echo and buffering for console games. |
| **SIGPIPE Signal Suppression** | ❌ Process crash | ✅ Intercepted | Intercepts broken pipes via `sys_rt_sigaction` to prevent server termination during abrupt client browser disconnects. |
| **Dual-Language CLI & Live Logs** | ⚠️ Partial | ✅ Complete | Full English and Russian CLI help (`-help`, `-help -ru`) and real-time color-coded console HTTP access logs. |

---

## 2. Future Roadmap

### 🔜 Sprint 3: Cryptography, TLS 1.3 & Extended Protocols (v0.9.0)
- [ ] **Pure ASM TLS 1.3 Engine (RFC 8446)**:
  - TLS Record Layer parser (`0x16`, `ClientHello`, `ServerHello`).
  - x86-64 multiprecision math for **X25519 (ECDHE)** key agreement.
  - Session key derivation via **HKDF-SHA256**.
  - Symmetric AEAD encryption: hardware-accelerated **AES-128-GCM** (`aesenc`/`pclmulqdq`) and **ChaCha20-Poly1305**.
  - Built-in minimal self-signed X.509 DER ASN.1 certificate generator.
- [ ] **Native FTP Server (RFC 959)**:
  - Autonomous FTP daemon on `mode "net"`: `USER`, `PASS`, `PWD`, `SYST`, `PORT`, `LIST`, `RETR`, `QUIT`.
- [ ] **DPI-Bypass Proxy Tunneling**:
  - Header parsers and stream routing for **VLESS** (UUID) and **Trojan** (SHA-224).

### 🔜 Sprint 4: Cross-Platform Windows PE32+ (v1.0.0)
- [ ] **Native PE32+ (.exe) Generator**:
  - Direct synthesis of DOS MZ Stub, PE Signature, COFF Header, Optional Header (PE32+ 64-bit).
  - Section table management (`.text`, `.rdata`, `.data`).
  - Import Address Table (IAT / `.idata`) synthesizer linking directly to `kernel32.dll` and `ws2_32.dll` without MinGW/MSVC.

### 🔭 Long-Term Vision
- [ ] **RamisBrowser Engine**: Ultra-lightweight native web browser powered by custom text rendering and the RSMC network stack.

---

## 3. Compatibility Matrix

| Feature / Subsystem | Linux ELF64 (AOT) | JIT Engine (RAM) | RSE Container | Bare-Metal MBR (`-img`) | Windows PE32+ (Roadmap) |
|---|:---:|:---:|:---:|:---:|:---:|
| **x86-64 Integer ALU (+, -, \*, ^, &, >>, <<)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 Planned v1.0 |
| **Registers (RAX-R15, RSP, RBP)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 Planned v1.0 |
| **SIMD SSE Operations (`xmm0`-`xmm7`)** | ✅ 100% | ✅ 100% | ⚠️ Basic | ✅ 100% | 🔄 Planned v1.0 |
| **`mode "vars"` (mut, buf, struct, &addr)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 Planned v1.0 |
| **`mode "logic"` (&&, \|\|, !, brackets)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 Planned v1.0 |
| **`mode "kids"` (color, locate, say, repeat)** | ✅ 100% | ✅ 100% | ✅ 100% | ❌ Requires OS | 🔄 Planned v1.0 |
| **`mode "sys"` (open, read, write, close, exit)** | ✅ 100% | ✅ 100% | ✅ 100% | ❌ Ring 3 Only | 🔄 Win32 API |
| **`mode "net"` (listen, accept, send, recv)** | ✅ 100% | ✅ 100% | ✅ 100% | ❌ Requires Stack | 🔄 Winsock2 |
| **Zero-Copy `net.sendfile`** | ✅ 100% | ✅ 100% | ⚠️ Emulated | ❌ No VFS | 🔄 TransmitFile |
| **`mode "osdev"` (cli, sti, hlt, inb, outb, cr0)** | ❌ Ring 3 Trap | 🛡️ Intercepted | ❌ Denied | ✅ 100% (Ring 0) | ❌ Denied |
| **Raw Microcode (`call hex`)** | ✅ 100% | ✅ 100% | ❌ Denied | ✅ 100% | 🔄 Planned v1.0 |
| **Dynamic Memory (`new`, `enable GC`)** | ✅ 100% | ✅ 100% | ✅ 100% | ⚠️ Static Pool | 🔄 Planned v1.0 |

---

## 4. Execution Targets & CLI Reference

```bash
# 1. Compile directly to standalone native Linux ELF64 binary
ramisc source.rsmc binary_name

# 2. Run instantly in memory via built-in JIT engine
ramisc -jit source.rsmc

# 3. Compile to portable RSE binary container
ramisc -rse source.rsmc app.rse

# 4. Execute RSE container via integrated runtime
ramisc -run app.rse

# 5. Build 16KB bootable bare-metal MBR disk image
ramisc -img source.rsmc minios.img

# 6. Display version and multilingual help
ramisc --version
ramisc -help
ramisc -help -ru
```

---

## 5. Language Modes (`mode`)

Higher-level language features require explicit opt-in to eliminate hidden runtime costs:

| Directive | Description & Syntax |
|---|---|
| `mode "vars"` | Stack variables (`mut x: qword = 0`), static memory buffers (`buf b: 64`), structured data (`struct`), field offsets (`pt.x`), and address-of operator (`&var`). |
| `mode "logic"` | Compound boolean operators (`&&`, `\|\|`, `!`), branch conditions, and parenthesized expressions `(a + b) * c`. |
| `mode "kids"` | Terminal graphics: `color("red")`, `locate(x, y)`, string output `say`, numeric printing `say_num(reg)`, audio `beep`, delays `sleep(ms)`, and loops `repeat N do { ... }`. |
| `mode "sys"` | Direct Linux system call wrappers: `sys.open`, `sys.read`, `sys.write`, `sys.close`, `sys.socket`, `sys.exit`. |
| `mode "net"` | High-performance TCP socket layer: `net.listen(port)`, `net.accept(srv)`, `net.recv(client, &buf, len)`, `net.send(client, &buf, len)`, `net.sendfile(client, fd, len)`, `net.close(fd)`. |
| `mode "osdev"` | Privileged bare-metal Ring 0 instructions: `cli`, `sti`, `hlt`, port I/O `inb(port)`, `outb port, val`, and control register access `rax = cr0`. |
| `mode "yeah, i am a loser"` | High-level convenience mode providing classic standard string printing: `print "Hello World\n"`. |

---

## 6. Flagship Showcase Projects

### 1. Interactive Live Server (`liveserver.rsmc`)
Real-time console HTTP server displaying incoming browser connections with colored ANSI tags.
* **Port**: `8081`
* **Static Assets**: `index.html`, `style.css`, `app.js`
* **Build & Run**:
  ```bash
  ramisc liveserver.rsmc liveserver
  ./liveserver
  ```
* **Test**: Navigate to `http://localhost:8081/` or run `curl -i [http://127.0.0.1:8081/](http://127.0.0.1:8081/)`
* **Stop**: Press `Ctrl+C`

### 2. Background Zero-Copy Daemon (`server.rsmc`)
High-throughput daemon that streams static files directly from kernel page cache into client sockets via `net.sendfile`.
* **Port**: `8080`
* **Build & Run in Background**:
  ```bash
  ramisc server.rsmc web_server
  ./web_server &
  ```
* **Test**: Run `curl -i [http://127.0.0.1:8080/](http://127.0.0.1:8080/)`
* **Stop**: Run `pkill -9 -f web_server`

### 3. Non-Blocking Console Snake (`snake.rsmc`)
Terminal arcade game utilizing `ioctl` Raw Mode for instant key handling without Enter or character echoing.
* **Build & Run**:
  ```bash
  ramisc snake.rsmc snake
  ./snake
  ```
* **Controls**: `W`, `A`, `S`, `D` to change direction, `Q` to exit cleanly.

### 4. Bare-Metal MiniOS Kernel (`bare_minios.rsmc`)
Autonomous 64-bit OS kernel booting from raw disk sectors into Long Mode and rendering directly to VGA hardware memory (`0xB8000`).
* **Build & Launch in QEMU**:
  ```bash
  ramisc -img bare_minios.rsmc minios.img
  qemu-system-x86_64 -drive format=raw,file=minios.img
  ```

---
---

<a name="русский"></a>
# Документация на русском языке

**RamisScript (RSMC)** — это низкоуровневый bare-metal язык системного программирования и автономный компилятор прямого действия для архитектуры x86-64 (AMD64), разработанный с нуля на чистом ассемблере FASM Валерием Кравченко (KV/RaMIS Project Group).

Компилятор функционирует **без использования библиотек Си (libc), CRT0 и внешних линкеров**. Трансляция кода из узлов AST напрямую генерирует процессорные инструкции x86-64 в:
* Автономные исполняемые файлы формата **ELF64** для Linux с прямыми вызовами ядра `syscall`.
* Исполняемые страницы оперативной памяти для мгновенного выполнения через встроенный **JIT** (`sys_mmap`).
* Переносимые бинарные байткод-пакеты (**RSE** - RamisScript Executable).
* Сырые 16-килобайтные загрузочные **MBR-образы дисков**, переводящие процессор в 64-битный Long Mode.

---

## 1. Что нового в версии v0.8.0 (Сравнение с v0.7.0)

| Компонент / Возможность | Состояние в v0.7.0 | Реализация в v0.8.0 | Технические подробности |
|---|:---:|:---:|---|
| **Сетевой стек (`mode "net"`)** | ❌ Отсутствовал | ✅ Реализован на 100% | Полная поддержка сокетов TCP L4: `net.listen` (с опцией `SO_REUSEADDR`), `net.accept`, `net.send`, `net.recv`, `net.close`. |
| **Аппаратный Zero-Copy `sendfile`** | ❌ Отсутствовал | ✅ Реализован на 100% | Использование сисколла Linux `sys_sendfile` для передачи страниц из дискового кэша в сетевой сокет без копирования в userspace. |
| **Bare-Metal MBR Генератор (`-img`)** | ❌ Отсутствовал | ✅ Реализован на 100% | Сборка 16KB сырого образа диска: MBR сектор (`0xAA55`), переключение из Real Mode в Protected Mode, 4-уровневые таблицы страниц и Long Mode. |
| **Защита JIT от Ring 0 инструкций** | ⚠️ Авария SIGSEGV | ✅ Полная изоляция | Автоматический перехват привилегированных команд (`cli`, `sti`, `hlt`, `cr0`, порты) в JIT-режиме с выводом понятной ошибки. |
| **Терминальный Raw Mode** | ❌ Только канонический | ✅ Реализован | Прямой вызов `ioctl(0, TCGETS/TCSETS)`: побайтовый неблокирующий ввод (`VMIN=0, VTIME=0`) без эхо-печати и без нажатия клавиши Enter. |
| **Подавление сигналов `SIGPIPE`** | ❌ Обрыв процесса | ✅ Перехват через ядро | Перехват `SIGPIPE` через `sys_rt_sigaction`, исключающий аварийное завершение веб-сервера при закрытии вкладок в браузере. |
| **Двуязычный интерфейс и логирование** | ⚠️ Частично | ✅ Полная интеграция | Двуязычная справка CLI (`-help`, `-help -ru`), цветные логи веб-серверов в реальном времени с точными метками времени. |

---

## 2. Технический план развития (Roadmap)

### 🔜 Спринт 3: Криптография, TLS 1.3 и Сетевые протоколы (v0.9.0)
- [ ] **Нативный криптографический движок TLS 1.3 (RFC 8446)**:
  - Разбор протокола рукопожатия TLS Record Layer (`0x16`, `ClientHello`, `ServerHello`).
  - Арифметика больших чисел x86-64 для эллиптической кривой **X25519 (ECDHE)**.
  - Деривация сессионных ключей шифрования через **HKDF-SHA256**.
  - Симметричное AEAD-шифрование: аппаратное **AES-128-GCM** (`aesenc`/`pclmulqdq`) и программное **ChaCha20-Poly1305**.
  - Встроенный самоподписанный сертификат X.509 в формате ASN.1 DER.
- [ ] **Автономный сервер FTP (RFC 959)**:
  - Полнофункциональный FTP-демон на `mode "net"`: команды `USER`, `PASS`, `PWD`, `SYST`, `PORT`, `LIST`, `RETR`, `QUIT`.
- [ ] **Сетевое туннелирование (DPI-Bypass)**:
  - Разбор заголовков и проброс потока для протоколов **VLESS** (UUID) и **Trojan** (SHA-224).

### 🔜 Спринт 4: Поддержка Windows PE32+ (v1.0.0)
- [ ] **Нативный генератор PE32+ (.exe)**:
  - Синтез заголовков Portable Executable для Windows x64: DOS MZ Stub, PE Signature, COFF Header, Optional Header PE32+.
  - Таблица секций `.text`, `.rdata`, `.data`.
  - Генерация Таблицы Импорта (IAT / `.idata`) для прямого вызова функций `kernel32.dll` и `ws2_32.dll` без внешних библиотек.

### 🔭 Долгосрочная перспектива
- [ ] **Движок RamisBrowser**: Минималистичный графический веб-браузер на базе собственного текстового рендерера и сетевого стека RSMC.

---

## 3. Матрица совместимости возможностей языка

| Возможность / Режим | Linux ELF64 (AOT) | JIT Engine (ОЗУ) | RSE Контейнер | Bare-Metal MBR (`-img`) | Windows PE32+ (Roadmap) |
|---|:---:|:---:|:---:|:---:|:---:|
| **Арифметика x86-64 (+, -, \*, ^, &, >>, <<)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 План v1.0 |
| **Регистры общего назначения (RAX-R15)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 План v1.0 |
| **Векторные команды SIMD (`xmm0`-`xmm7`)** | ✅ 100% | ✅ 100% | ⚠️ Базовый | ✅ 100% | 🔄 План v1.0 |
| **`mode "vars"` (mut, buf, struct, &addr)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 План v1.0 |
| **`mode "logic"` (&&, \|\|, !, скобки)** | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | 🔄 План v1.0 |
| **`mode "kids"` (color, locate, say, repeat)** | ✅ 100% | ✅ 100% | ✅ 100% | ❌ Нужна ОС | 🔄 План v1.0 |
| **`mode "sys"` (open, read, write, close, exit)** | ✅ 100% | ✅ 100% | ✅ 100% | ❌ Только Ring 3 | 🔄 Win32 API |
| **`mode "net"` (listen, accept, send, recv)** | ✅ 100% | ✅ 100% | ✅ 100% | ❌ Нужен стек | 🔄 Winsock2 |
| **Zero-Copy `net.sendfile`** | ✅ 100% | ✅ 100% | ⚠️ Эмуляция | ❌ Нет ФС ядра | 🔄 TransmitFile |
| **`mode "osdev"` (cli, sti, hlt, inb, outb, cr0)** | ❌ Ring 3 Защита | 🛡️ Перехват | ❌ Запрещено | ✅ 100% (Ring 0) | ❌ Запрещено |
| **Прямые HEX-инъекции (`call hex`)** | ✅ 100% | ✅ 100% | ❌ Запрещено | ✅ 100% | 🔄 План v1.0 |
| **Управление памятью (`new`, `enable GC`)** | ✅ 100% | ✅ 100% | ✅ 100% | ⚠️ Статический пул | 🔄 План v1.0 |

---

## 4. Способы сборки и справочник CLI

```bash
# 1. Компиляция в автономный монолитный бинарник Linux ELF64
ramisc source.rsmc binary_name

# 2. Мгновенный запуск в оперативной памяти через JIT-компилятор
ramisc -jit source.rsmc

# 3. Сборка в компактный бинарный байткод-контейнер .rse
ramisc -rse source.rsmc app.rse

# 4. Запуск скомпилированного .rse файла встроенным рантаймом
ramisc -run app.rse

# 5. Сборка 16-килобайтного загрузочного MBR-диска для bare-metal
ramisc -img source.rsmc minios.img

# 6. Версия компилятора и двуязычная справка
ramisc --version
ramisc -help
ramisc -help -ru
```

---

## 5. Таблица директив компилятора (`mode`)

По умолчанию компилятор работает в строгом регистровом режиме без неявного оверхеда. Высокоуровневые возможности подключаются директивами в начале файла:

| Директива | Описание и синтаксические конструкции |
|---|---|
| `mode "vars"` | Локальные переменные на стеке (`mut x: qword = 0`), статические буферы (`buf b: 64`), структуры (`struct`), смещения полей (`pt.x`), взятие адреса памяти (`&var`). |
| `mode "logic"` | Составные булевы операторы (`&&`, `\|\|`, `!`), условные конструкции и скобочные выражения с учетом приоритета `(a + b) * c`. |
| `mode "kids"` | Консольный интерфейс ANSI: выбор цвета `color("red")`, позиционирование `locate(x, y)`, вывод строк `say`, печать чисел `say_num(reg)`, звук `beep`, паузы `sleep(ms)`, циклы `repeat N do { ... }`. |
| `mode "sys"` | Прямые системные вызовы Linux: `sys.open`, `sys.read`, `sys.write`, `sys.close`, `sys.socket`, `sys.exit`. |
| `mode "net"` | Сетевой стек протокола TCP: `net.listen(port)`, `net.accept(srv)`, `net.recv(client, &buf, len)`, `net.send(client, &buf, len)`, `net.sendfile(client, fd, len)`, `net.close(fd)`. |
| `mode "osdev"` | Привилегированные инструкции Ring 0: `cli`, `sti`, `hlt`, порты ввода-вывода `inb(port)`, `outb port, val`, системные регистры `rax = cr0`. |
| `mode "yeah, i am a loser"` | Режим быстрой разработки со стандартной функцией печати строковых литералов: `print "Привет Мир\n"`. |

---

## 6. Четыре флагманских проекта релиза

### 1. `liveserver.rsmc` — Интерактивный Live-сервер с логами
Консольный веб-сервер на переднем плане с двуязычным баннером и выводом цветных статусов входящих запросов в реальном времени.
* **Выделенный порт**: `8081`
* **Файлы фронтенда**: `index.html`, `style.css`, `app.js`
* **Сборка и запуск**:
  ```bash
  ramisc liveserver.rsmc liveserver
  ./liveserver
  ```
* **Проверка**: Откройте `http://localhost:8081/` в браузере или в терминале: `curl -i [http://127.0.0.1:8081/](http://127.0.0.1:8081/)`
* **Остановка**: Нажмите комбинацию `Ctrl+C`.

### 2. `server.rsmc` — Фоновый Zero-Copy веб-сервер
Высокопроизводительный фоновый демон для раздачи статических файлов без копирования страниц в userspace через сисколл `net.sendfile`.
* **Выделенный порт**: `8080`
* **Сборка и запуск в фоне**:
  ```bash
  ramisc server.rsmc web_server
  ./web_server &
  ```
* **Проверка**: `curl -i [http://127.0.0.1:8080/](http://127.0.0.1:8080/)`
* **Остановка демона**: `pkill -9 -f web_server`

### 3. `snake.rsmc` — Автономная Змейка в Raw Mode
Консольная аркада, использующая побайтовый неблокирующий режим терминала без буферизации ввода и без необходимости жать Enter.
* **Сборка и запуск**:
  ```bash
  ramisc snake.rsmc snake
  ./snake
  ```
* **Управление**: `W`, `A`, `S`, `D` — перемещение, `Q` — выход с корректным восстановлением настроек терминала.

### 4. `bare_minios.rsmc` — Операционная система Bare-Metal
Самостоятельное 64-битное ядро, запускаемое на реальном процессоре или в QEMU без Linux с прямой отрисовкой в текстовый буфер видеокарты (`0xB8000`).
* **Сборка и запуск в эмуляторе**:
  ```bash
  ramisc -img bare_minios.rsmc minios.img
  qemu-system-x86_64 -drive format=raw,file=minios.img
  ```

---

## 7. Сборка и установка компилятора

### Требования к системе:
- Операционная система: **Linux x86-64 (Fedora, Arch, Ubuntu, Debian и др.)**
- Ассемблер: **Flat Assembler (`fasm`) версии 1.73+**
- Опционально для запуска ОС: **`qemu-system-x86_64`**

### Инсталляция:
```bash
# 1. Нативная сборка бинарника компилятора
fasm main.asm ramisc

# 2. Установка в пользовательскую системную директорию ~/.local/bin
./install.sh

# 3. Проверка установленной версии
ramisc --version
```

---

## 8. Лицензия / License

Проект распространяется под свободной лицензией **MIT License**.

```
Copyright (c) 2026 Valeriy Kravchenko (KV/RaMIS Project Group).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
