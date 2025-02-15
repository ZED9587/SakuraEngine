options no_unused_block_arguments = false
options no_unused_function_arguments = false
options no_global_variables = false
options indenting = 4
options strict_smart_pointers = true

module json shared public

require daslib/strings_boost

variant JsValue
    //! Single JSON element.
    _object : table<string; JsonValue?>
    _array  : array<JsonValue?>
    _string : string
    _number : double
    _bool   : bool
    _null   : void?

struct JsonValue
    //! JSON value, wraps any JSON element.
    value : JsValue

variant Token
    //! JSON input stream token.
    _string : string
    _number : double
    _bool   : bool
    _null   : void?
    _symbol : int
    _error  : string

let private
    Token_string = typeinfo(variant_index<_string> type<Token>) //! index of the
    Token_symbol = typeinfo(variant_index<_symbol> type<Token>)

def JV ( v : string )
    //! Creates `JsonValue` out of value.
    return new [[JsonValue value <- [[JsValue _string = v]]]]

def JV ( v : double )
    return new [[JsonValue value <- [[JsValue _number = v]]]]

def JV ( v : bool )
    return new [[JsonValue value <- [[JsValue _bool = v]]]]

def JVNull
    //! Creates `JsonValue` representing `null`.
    return new [[JsonValue value <- [[JsValue _null = null]]]]

def JV ( var v : table<string;JsonValue?> )
    return new [[JsonValue value <- [[JsValue _object <- v]]]]

def JV ( var v : array<JsonValue?> )
    return new [[JsonValue value <- [[JsValue _array <- v]]]]

def private lexer ( text : string )
    let stext = clone_string(text)
    return <- _lexer(stext)

def private lexer ( text : array<uint8> )
    let stext = string(text)
    return <- _lexer(stext)

def private _lexer ( var stext : string implicit )
    return <- generator<Token>() <|
        var tin : iterator<int>
        unsafe
            tin <- each(stext)
        var ahead : int = ' '
        var str : array<uint8>
        while !empty(tin)
            while is_white_space(ahead) && next(tin,ahead)
                pass
            if empty(tin)
                return false
            if ahead=='[' || ahead==']' || ahead=='{' || ahead=='}' || ahead==':' || ahead==','
                yield [[Token _symbol=ahead]]
                next(tin, ahead)
            elif ahead=='"'
                while next(tin,ahead) && ahead!='"'
                    if ahead == '\\'
                        if next(tin,ahead)
                            if ahead=='b'
                                ahead = '\b'
                            elif ahead=='f'
                                ahead = '\f'
                            elif ahead=='n'
                                ahead = '\n'
                            elif ahead=='r'
                                ahead = '\r'
                            elif ahead=='t'
                                ahead = '\t'
                            elif ahead=='u'
                                ahead = int(0x5c)
                            push(str,uint8(ahead))
                        else
                            yield [[Token _error = "string escape sequence exceeds text"]]
                            return false
                    else
                        push(str,uint8(ahead))
                if empty(tin)
                    yield [[Token _error = "string exceeds text"]]
                    return false
                yield [[Token _string = string(str)]]
                clear(str)
                next(tin, ahead)
            elif ahead=='+' || ahead=='-' || is_number(ahead)
                push(str,uint8(ahead))
                var anyNumbers = is_number(ahead)
                while next(tin,ahead) && is_number(ahead)
                    push(str,uint8(ahead))
                    anyNumbers = true
                if !empty(tin) && ahead=='.'
                    push(str,uint8(ahead))
                    while next(tin,ahead) && is_number(ahead)
                        push(str,uint8(ahead))
                        anyNumbers = true
                if !empty(tin) && (ahead=='e' || ahead=='E')
                    push(str,uint8(ahead))
                    next(tin,ahead)
                    if ahead=='+' || ahead=='-' || is_number(ahead)
                        push(str,uint8(ahead))
                    while next(tin,ahead) && is_number(ahead)
                        push(str,uint8(ahead))
                        anyNumbers = true
                var num = string(str)
                if !anyNumbers
                    yield [[Token _error = "invalid number {num}"]]
                    return false
                yield [[Token _number = double(num)]]
                clear(str)
                unsafe
                    delete_string(num)
            elif is_alpha(ahead)
                push(str,uint8(ahead))
                while next(tin,ahead) && is_alpha(ahead)
                    push(str,uint8(ahead))
                var name = string(str)
                if name == "true"
                    yield [[Token _bool=true]]
                elif name == "false"
                    yield [[Token _bool=false]]
                elif name == "null"
                    yield [[Token _null = null]]
                else
                    yield [[Token _error = "invalid name {name}"]]
                    return false
                unsafe
                    delete_string(name)
                clear(str)
            else
                yield [[Token _error = "invalid character `{to_char(ahead)}` aka ASCII {ahead}"]]
                return false
        return false
    finally
        unsafe
            delete_string(stext)

def private expect_token ( var itv : iterator<Token>; var ahead : Token; vindex : int; var error : string & ) : bool
    if !next(itv, ahead)
        error = "unexected eos"
        return false
    elif variant_index(ahead) != vindex
        error = "unexpected {ahead}, expecting variant {vindex}"
        return false
    else
        return true

def private expect_symbol ( var itv : iterator<Token>; var ahead : Token; sym : int; var error : string & ) : bool
    if !next(itv, ahead)
        error = "unexected eos"
        return false
    elif ! ahead is _symbol
        error = "unexpected {ahead}, expecting symbol"
        return false
    elif !(ahead as _symbol == sym)
        error = "unexpected {ahead}, expecting symbol `{to_char(sym)}` aka ASCII {sym}"
        return true
    else
        return true

def private parse_value ( var itv : iterator<Token>; var error : string & ) : JsonValue?
    var ahead : Token
    if !next(itv, ahead)
        return null
    if ahead is _symbol
        let sym = ahead as _symbol
        if sym == ']'
            error = "unexpected ]"
            return null
        if sym == '['
            var arr : array<JsonValue?>
            while !empty(itv)
                let value = parse_value(itv, error)
                if value == null
                    if error=="unexpected ]" && length(arr)==0
                        error = ""
                        return JV(arr)
                    return null
                push(arr, value)
                if !expect_token(itv, ahead, Token_symbol, error)
                    return null
                let sepsym = ahead as _symbol
                if sepsym == ']'
                    break
                elif sepsym != ','
                    error = "unsepected array seaprator symbol `{to_char(sepsym)}` aka ASCII {sepsym}"
                    return null
            if empty(itv)
                error = "unexpected eos"
                return null
            return JV(arr)
        elif sym == '{'
            var tab : table<string; JsonValue?>
            while !empty(itv)
                if !expect_token(itv, ahead, Token_string, error)
                    if (ahead is _symbol) && (ahead as _symbol)=='}' && length(tab)==0
                        error = ""
                        return JV(tab)
                    return null
                let key = ahead as _string
                if !expect_symbol(itv, ahead, ':', error)
                    return null
                let value = parse_value(itv, error)
                if value == null
                    return null
                if !allow_duplicate_keys && key_exists(tab,key)
                    error = "duplicate key {key}"
                    return null
                tab[key] = value
                if !expect_token(itv, ahead, Token_symbol, error)
                    return null
                let sepsym = ahead as _symbol
                if sepsym == '}'
                    break
                elif sepsym != ','
                    error = "unsepected object seaprator symbol `{to_char(sepsym)}` aka ASCII {sepsym}"
                    return null
            if empty(itv)
                error = "unexpected eos"
                return null
            return JV(tab)
        else
            error = "unexpected symbol `{to_char(sym)}` aka ASCII {sym}"
            return null
    elif ahead is _string
        return JV(ahead as _string)
    elif ahead is _number
        return JV(ahead as _number)
    elif ahead is _bool
        return JV(ahead as _bool)
    elif ahead is _null
        return JVNull()
    else
        error = "{ahead}"
        return null

def read_json ( text : string implicit; var error : string& ) : JsonValue?
    //! reads JSON from the `text` string.
    //! if `error` is not empty, it contains the parsing error message.
    error = ""
    var lex <- lexer(text)
    let res = parse_value(lex,error)
    delete lex
    return res

def read_json ( text : array<uint8>; var error : string& ) : JsonValue?
    error = ""
    var lex <- lexer(text)
    let res = parse_value(lex,error)
    delete lex
    return res

var private no_trailing_zeros = false

def set_no_trailing_zeros ( value : bool )
    let old_ntz = no_trailing_zeros
    no_trailing_zeros = value
    return old_ntz

var private no_empty_arrays = false

def set_no_empty_arrays ( value : bool )
    let old_nea = no_empty_arrays
    no_empty_arrays = value
    return old_nea

var private allow_duplicate_keys = false

def set_allow_duplicate_keys ( value : bool )
    let old_adc = allow_duplicate_keys
    allow_duplicate_keys = value
    return old_adc

// note - we use StringBuilderWriter for performance reasons here
def private write_value ( var writer : StringBuilderWriter; jsv : JsonValue?; depth : int )
    if jsv == null
        write(writer, "null")
    elif jsv.value is _string
        write(writer, "\"")
        write_escape_string(writer, jsv.value as _string)
        write(writer, "\"")
    elif jsv.value is _number
        if no_trailing_zeros
            write(writer, format("%.17f",jsv.value as _number) |> rtrim("0") |> rtrim("."))
        else
            write(writer, jsv.value as _number)
    elif jsv.value is _array
        if length(jsv.value as _array)==0
            write(writer, "[]")
        else
            write(writer, "[\n")
            var first = true
            for elem in jsv.value as _array
                if first
                    first = false
                else
                    write(writer,",\n")
                write_chars(writer,'\t',depth+1)
                write_value(writer, elem, depth+1)
            write(writer, "\n")
            write_chars(writer,'\t',depth)
            write(writer, "]")
    elif jsv.value is _object
        if length(jsv.value as _object)==0
            write(writer, "\{\}")
        else
            write(writer, "\{\n")
            var first = true
            for elemK, elemV in keys(jsv.value as _object), values(jsv.value as _object)
                if no_empty_arrays
                    if elemV.value is _array
                        if length(elemV.value as _array)==0
                            continue
                if first
                    first = false
                else
                    write(writer,",\n")
                write_chars(writer,'\t',depth+1)
                write(writer, "\"")
                write_escape_string(writer, elemK)
                write(writer, "\" : ")
                write_value(writer, elemV, depth+1)
            write(writer, "\n")
            write_chars(writer,'\t',depth)
            write(writer, "\}")
    elif jsv.value is _bool
        if jsv.value as _bool
            write(writer, "true")
        else
            write(writer, "false")
    elif jsv.value is _null
        write(writer, "null")
    else
        panic("unexpected {jsv}")

def write_json ( val : JsonValue? ) : string
    //! returns JSON (textual) representation of JsonValue as a string.
    let st = build_string() <| $ (var writer)
        write_value(writer, val, 0)
    return st

def try_fixing_broken_json ( var bad:string )
    //! fixes broken json. so far supported
    //! 1. "string" + "string" string concatination
    //! 2. "text "nested text" text" nested quotes
    //! 3. extra , at the end of object or array
    //! 4. /uXXXXXX sequences in the middle of white space
	return build_string <| $ ( writer )
		peek_data(bad) <| $ ( str )
			var i = 0
			let lstr = length(str)
			while i < lstr
				// write until begining of string or end
				while i < lstr && str[i]!='"'u8
                    if str[i]==','u8
                        var j = i + 1
                        while j < lstr && is_white_space(int(str[j]))
                            j ++
                        if j < lstr && (str[j]=='}'u8 || str[j]==']'u8)
                            i = j
                            continue
                    if str[i]=='\\'u8 && str[i+1]=='u'u8
                        i +=2
                        while i < lstr && is_hex(int(str[i]))
                            i ++
                        continue
					writer |> write_char(int(str[i]))
					i ++
				if i >= lstr	// if eof we done
					break
				// write the first quote
				writer |> write_char('"')
				i ++
				// write until end of string or end of file
				label 0:
				while i < lstr && str[i]!='"'u8
					writer |> write_char(int(str[i]))
					i ++
				if i >= lstr	// if eof we done, we fix close quote and we are done
					writer |> write_char('"')
					break
				// skipping whitespace
				let nested = i
				var j = i + 1
                let any_white_space = j < lstr && is_white_space(int(str[j]))
				while j < lstr && is_white_space(int(str[j]))
					j ++
				if j >= lstr	// if eof we done, we fix close quote and we are done
					writer |> write_char('"')
					break
				// valid JSON things after string are :, }, ], or , if its one of those, we close the string and we are done
				let strj = int(str[j])
				if strj==':' || strj=='}' || strj==']' || strj==','
					writer |> write_char('"')
					i ++
					continue
				// now, if its a + - it could be a string concatenation
				if strj=='+'
					j ++
					while j < lstr && is_white_space(int(str[j]))
						j ++
					if j < lstr && str[j]=='"'u8	// if it is indeed new string, we go back to string writing, and add a separator
						writer |> write_char(' ')
						i = j + 1
						goto label 0
				// ok, its not a string concatination, or a valid character
                // if it was a whitespace after the quote, we assume its missing ','
                if any_white_space
                    writer |> write_char('"')
                    writer |> write_char(',')
                    i = nested + 1
                    continue
                // . we assume its nested quotes and we replace with \"
				writer |> write("`")
				i = nested + 1
				while i < lstr && str[i]!='"'u8
					writer |> write_char(int(str[i]))
					i ++
				if i >= lstr	// if eof we done, we fix nested quote and and closing quote and we are done
					writer |> write("`")
					writer |> write_char('"')
					break
				// write the second replaced quote
				writer |> write("`")
				i ++
				goto label 0
