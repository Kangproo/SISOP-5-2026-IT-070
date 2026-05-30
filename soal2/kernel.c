int cursor = 0;
char color = 0x07;

void putInMemory(int segment, int address, char character);
int getChar();

int divInt(int a, int b);
int modInt(int a, int b);

void printChar(char c);
void printString(char *str);
void newline();
void clearScreen();
void readString(char *buf);

int strcmp(char *a, char *b);
int startsWith(char *str, char *prefix);
int atoi(char *str);
void intToString(int num, char *buf);
int factorial(int n);
void getArg(char *cmd, int index, char *out);
void handleCommand(char *cmd);

int divInt(int a, int b) {
    int count;

    count = 0;

    while (a >= b) {
        a = a - b;
        count++;
    }

    return count;
}

int modInt(int a, int b) {
    while (a >= b) {
        a = a - b;
    }

    return a;
}

void printChar(char c) {
    int addr;
    int col;

    if (c == '\n') {
        col = modInt(cursor, 80);
        cursor = cursor + (80 - col);
        return;
    }

    if (c == '\b') {
        if (cursor > 0) {
            cursor--;
            addr = cursor * 2;
            putInMemory(0xB800, addr, ' ');
            putInMemory(0xB800, addr + 1, color);
        }
        return;
    }

    addr = cursor * 2;
    putInMemory(0xB800, addr, c);
    putInMemory(0xB800, addr + 1, color);
    cursor++;

    if (cursor >= 80 * 25) {
        clearScreen();
    }
}

void printString(char *str) {
    int i;

    i = 0;

    while (str[i] != 0) {
        printChar(str[i]);
        i++;
    }
}

void newline() {
    printChar('\n');
}

void clearScreen() {
    int i;
    int addr;

    for (i = 0; i < 80 * 25; i++) {
        addr = i * 2;
        putInMemory(0xB800, addr, ' ');
        putInMemory(0xB800, addr + 1, color);
    }

    cursor = 0;
}

void readString(char *buf) {
    int i;
    char c;

    i = 0;

    while (1) {
        c = getChar();

        if (c == 13) {
            buf[i] = 0;
            return;
        }

        if (c == 8) {
            if (i > 0) {
                i--;
                printChar('\b');
            }
        } else {
            if (i < 63) {
                buf[i] = c;
                i++;
                printChar(c);
            }
        }
    }
}

int strcmp(char *a, char *b) {
    int i;

    i = 0;

    while (a[i] != 0 && b[i] != 0) {
        if (a[i] != b[i]) {
            return 0;
        }
        i++;
    }

    if (a[i] == b[i]) {
        return 1;
    }

    return 0;
}

int startsWith(char *str, char *prefix) {
    int i;

    i = 0;

    while (prefix[i] != 0) {
        if (str[i] != prefix[i]) {
            return 0;
        }
        i++;
    }

    return 1;
}

int atoi(char *str) {
    int i;
    int result;

    i = 0;
    result = 0;

    while (str[i] == ' ') {
        i++;
    }

    while (str[i] >= '0' && str[i] <= '9') {
        result = result * 10 + (str[i] - '0');
        i++;
    }

    return result;
}

void intToString(int num, char *buf) {
    int i;
    int j;
    int temp;
    char rev[16];

    i = 0;

    if (num == 0) {
        buf[0] = '0';
        buf[1] = 0;
        return;
    }

    if (num < 0) {
        buf[i] = '-';
        i++;
        num = -num;
    }

    j = 0;

    while (num > 0) {
        temp = modInt(num, 10);
        rev[j] = temp + '0';
        num = divInt(num, 10);
        j++;
    }

    while (j > 0) {
        j--;
        buf[i] = rev[j];
        i++;
    }

    buf[i] = 0;
}

int factorial(int n) {
    int i;
    int result;

    result = 1;

    if (n < 0) {
        return -1;
    }

    if (n > 7) {
        return -1;
    }

    for (i = 1; i <= n; i++) {
        result = result * i;
    }

    return result;
}

void getArg(char *cmd, int index, char *out) {
    int i;
    int arg;
    int j;

    i = 0;
    arg = 0;
    j = 0;

    while (cmd[i] != 0 && cmd[i] != ' ') {
        i++;
    }

    while (cmd[i] == ' ') {
        i++;
    }

    while (arg < index) {
        while (cmd[i] != 0 && cmd[i] != ' ') {
            i++;
        }

        while (cmd[i] == ' ') {
            i++;
        }

        arg++;
    }

    while (cmd[i] != 0 && cmd[i] != ' ') {
        out[j] = cmd[i];
        i++;
        j++;
    }

    out[j] = 0;
}

void handleCommand(char *cmd) {
    char arg1[32];
    char arg2[32];
    char result[32];
    int a;
    int b;
    int res;
    int i;
    int j;

    if (strcmp(cmd, "check")) {
        printString("ok");
        newline();
        return;
    }

    if (strcmp(cmd, "help")) {
        printString("check add sub fac season triangle clear about");
        newline();
        return;
    }

    if (strcmp(cmd, "about")) {
        printString("Assistant's Last Gift");
        newline();
        return;
    }

    if (strcmp(cmd, "clear")) {
        clearScreen();
        return;
    }

    if (startsWith(cmd, "add ")) {
        getArg(cmd, 0, arg1);
        getArg(cmd, 1, arg2);

        a = atoi(arg1);
        b = atoi(arg2);
        res = a + b;

        intToString(res, result);
        printString(result);
        newline();
        return;
    }

    if (startsWith(cmd, "sub ")) {
        getArg(cmd, 0, arg1);
        getArg(cmd, 1, arg2);

        a = atoi(arg1);
        b = atoi(arg2);
        res = a - b;

        intToString(res, result);
        printString(result);
        newline();
        return;
    }

    if (startsWith(cmd, "fac ")) {
        getArg(cmd, 0, arg1);

        a = atoi(arg1);
        res = factorial(a);

        if (res < 0) {
            printString("know your limit little bro.");
            newline();
        } else {
            intToString(res, result);
            printString(result);
            newline();
        }

        return;
    }

    if (startsWith(cmd, "season ")) {
        getArg(cmd, 0, arg1);

        if (strcmp(arg1, "winter")) {
            color = 0x09;
            printString("winter mode");
        } else if (strcmp(arg1, "spring")) {
            color = 0x0A;
            printString("spring mode");
        } else if (strcmp(arg1, "summer")) {
            color = 0x0E;
            printString("summer mode");
        } else if (strcmp(arg1, "fall")) {
            color = 0x06;
            printString("fall mode");
        } else if (strcmp(arg1, "radiant")) {
            color = 0x0D;
            printString("radiant mode");
        } else {
            printString("unknown season");
        }

        newline();
        return;
    }

    if (startsWith(cmd, "triangle ")) {
        getArg(cmd, 0, arg1);
        a = atoi(arg1);

        for (i = 1; i <= a; i++) {
            for (j = 0; j < i; j++) {
                printChar('x');
            }
            newline();
        }

        return;
    }

    printString("unknown command");
    newline();
}

void main() {
    char cmd[64];

    clearScreen();

    printString("Welcome to Assistant's Last Gift");
    newline();

    printString("type 'help'");
    newline();
    newline();

    while (1) {
        printString("> ");

        readString(cmd);

        newline();

        handleCommand(cmd);

        newline();
    }
}