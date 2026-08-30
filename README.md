# RamisScript (RSMC) v0.7.0

[English](#english) | [Русский](#русский)

---

## English

**RamisScript** is a baremetal, zero-overhead systems programming language and standalone JIT/AOT compiler written from scratch in pure x86_64 assembly (FASM) by a 15-year-old developer (Valeriy Kravchenko / KV/RaMIS Project Group).

The compiler does not rely on C, LLVM, GNU Assembler, or external linkers. It directly compiles `.rsmc` source files into:
1. Standalone native **ELF64** binaries for Linux.
2. Executable memory pages for instant **JIT execution** via `mmap`.
3. Custom **RSE** (RamisScript Executable) binary containers.

### Key Features
* **Direct Machine Code Generation:** Emits raw x86_64 opcodes directly from AST passes without intermediate assembler stages.
* **Modular Execution Modes (`mode`):** High-level language features (variables, logic operators, loops) require explicit opt-in to guarantee zero hidden runtime overhead.
* **Low-Level Hardware Injections:** Native support for raw HEX opcodes (`call hex`) and inline C execution blocks (`call C`).
* **Targeted Memory Management:** Selective Garbage Collection (`enable GC for: ...`) and priority scopes (`enable BLOCKS for: ...`) without global runtime penalty.

### Build & Installation
Prerequisites: Flat Assembler (`fasm`).

```bash
git clone [https://github.com/KVRaMISPG/RamisScript.git](https://github.com/KVRaMISPG/RamisScript.git)
cd RamisScript
chmod +x install.sh
./install.sh
```

### CLI Reference
```bash
# 1. Compile to standalone native ELF64 binary
ramisc source.rsmc binary_name

# 2. Run immediately in RAM via built-in JIT compiler
ramisc -jit source.rsmc

# 3. Build into a custom .rse binary container
ramisc -rse source.rsmc binary.rse

# 4. Execute an existing .rse binary container
ramisc -run binary.rse
```

### Directive System (`mode`)
By default, the compiler operates strictly in raw register mode. Higher-level abstractions are enabled explicitly per file:

| Directive | Description |
| :--- | :--- |
| `mode "sys"` | Enables system call wrappers: `sys.read`, `sys.write`, `sys.exit` |
| `mode "vars"` | Enables stack-allocated local variables (`mut x: qword = 0`) |
| `mode "logic"` | Enables compound logic (`&&`, `||`, `!`) and parenthesized expressions `()` |
| `mode "kids"` | Enables high-level loops (`repeat X do {}`) and `say` output |
| `mode "osdev"` | Enables baremetal I/O instructions: `inb`, `outb`, `cli`, `sti`, `hlt` |
| `mode "yeah, i am a loser"` | Enables classic `print` string output |

### Code Examples

#### 1. Minimal JIT Execution
```ramisscript
mode "sys"

main :: fn () {
    rax = 42
    sys.exit(rax)
}
```

#### 2. Engineering Calculator & High-Level Loops
```ramisscript
mode "sys"
mode "vars"
mode "kids"

main :: sub()
    mut counter: qword = 3

    repeat 3 do {
        say "Iterating with RamisScript JIT engine!"
    }

    sys.exit(0)
end
```

#### 3. Direct CPU Microcode Injection (HEX)
```ramisscript
mode "sys"

main :: sub()
    # Execute CPU timestamp counter (RDTSC) via raw opcodes
    call hex(end=EOI):{
        0f 31          # rdtsc (edx:eax)
        48 c1 e2 20    # shl rdx, 32
        48 09 d0       # or rax, rdx
    }EOI

    sys.exit(0)
end
```

---

## Русский

**RamisScript** — это низкоуровневый baremetal-язык программирования и автономный JIT/AOT-компилятор с нулевым оверхедом, написанный с нуля на чистом ассемблере x86_64 (FASM) 15-летним разработчиком (Валерий Кравченко / KV/RaMIS Project Group).

Компилятор не использует Си, LLVM, GNU Assembler или внешние линкеры. Он напрямую транслирует исходный код `.rsmc` в:
1. Автономные нативные исполняемые файлы **ELF64** для Linux.
2. Исполняемые страницы памяти для мгновенного запуска через встроенный **JIT** (`mmap`).
3. Собственные бинарные контейнеры **RSE** (RamisScript Executable).

### Основные возможности
* **Прямая генерация машинного кода:** Генерация опкодов x86_64 напрямую из AST без промежуточных компиляторов.
* **Модульная система режимов (`mode`):** Высокоуровневые конструкции (переменные, логика, циклы) включаются строго вручную для исключения неявного оверхеда.
* **Аппаратные инъекции:** Прямое внедрение шестнадцатеричного машинного кода (`call hex`) и C-блоков (`call C`).
* **Точечное управление памятью:** Выборочное подключение сборщика мусора (`enable GC for: ...`) и приоритетных областей видимости (`enable BLOCKS for: ...`).

### Сборка и установка
Требуется Flat Assembler (`fasm`).

```bash
git clone [https://github.com/KVRaMISPG/RamisScript.git](https://github.com/KVRaMISPG/RamisScript.git)
cd RamisScript
chmod +x install.sh
./install.sh
```

### Использование CLI
```bash
# 1. Компиляция в автономный нативный исполняемый файл ELF64
ramisc source.rsmc binary_name

# 2. Мгновенный запуск в оперативной памяти через встроенный JIT
ramisc -jit source.rsmc

# 3. Сборка в кастомный бинарный формат .rse
ramisc -rse source.rsmc binary.rse

# 4. Запуск скомпилированного .rse файла
ramisc -run binary.rse
```

### Таблица режимов (`mode`)
По умолчанию компилятор работает в строгом регистровом режиме. Высокоуровневые абстракции активируются директивами в начале файла:

| Директива | Описание |
| :--- | :--- |
| `mode "sys"` | Включает макросы системных вызовов: `sys.read`, `sys.write`, `sys.exit` |
| `mode "vars"` | Включает локальные переменные на стеке (`mut x: qword = 0`) |
| `mode "logic"` | Включает составные логические операторы (`&&`, `||`, `!`) и скобки `()` |
| `mode "kids"` | Включает циклы (`repeat X do {}`) и вывод текста через `say` |
| `mode "osdev"` | Включает низкоуровневые команды ввода-вывода: `inb`, `outb`, `cli`, `sti`, `hlt` |
| `mode "yeah, i am a loser"` | Включает функцию базовой печати `print` |

### Примеры программ

#### 1. Минимальная программа для JIT
```ramisscript
mode "sys"

main :: fn () {
    rax = 42
    sys.exit(rax)
}
```

#### 2. Работа со стеком и циклы
```ramisscript
mode "sys"
mode "vars"
mode "kids"

main :: sub()
    mut counter: qword = 3

    repeat 3 do {
        say "Iterating with RamisScript JIT engine!"
    }

    sys.exit(0)
end
```

#### 3. Прямая вставка машинного микрокода (HEX)
```ramisscript
mode "sys"

main :: sub()
    # Чтение счетчика тактов процессора (RDTSC) через сырые опкоды
    call hex(end=EOI):{
        0f 31          # rdtsc (edx:eax)
        48 c1 e2 20    # shl rdx, 32
        48 09 d0       # or rax, rdx
    }EOI

    sys.exit(0)
end
```

---

## License / Лицензия

(c) 2026 Valeriy Kravchenko (KV/RaMIS Project Group). Distributed under the MIT License.
