TOKEN_EOF         = 0
TOKEN_IDENTIFIER  = 1
TOKEN_NUMBER      = 2
TOKEN_STRING      = 3
TOKEN_OPERATOR    = 4
TOKEN_DELIMITER   = 5
TOKEN_KEYWORD     = 6
TOKEN_REGISTER    = 7
TOKEN_XMM         = 8
TOKEN_INDENT      = 9
TOKEN_DEDENT      = 10

struc Token {
    .type   dd ?
    .len    dd ?
    .ptr    dq ?
}
virtual at 0
    Token Token
end virtual