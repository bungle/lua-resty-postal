local ffi = require "ffi"
local ffi_cdef = ffi.cdef
local ffi_load = ffi.load
local ffi_gc = ffi.gc
local ffi_typeof = ffi.typeof
local ffi_new = ffi.new
local ffi_string = ffi.string
local type = type
local assert = assert
local tonumber = tonumber

ffi_cdef[[
typedef struct normalize_options {
    char **languages;
    int num_languages;
    uint16_t address_components;
    bool latin_ascii;
    bool transliterate;
    bool strip_accents;
    bool decompose;
    bool lowercase;
    bool trim_string;
    bool drop_parentheticals;
    bool replace_numeric_hyphens;
    bool delete_numeric_hyphens;
    bool split_alpha_from_numeric;
    bool replace_word_hyphens;
    bool delete_word_hyphens;
    bool delete_final_periods;
    bool delete_acronym_periods;
    bool drop_english_possessives;
    bool delete_apostrophes;
    bool expand_numex;
    bool roman_numerals;
} normalize_options_t;
normalize_options_t get_libpostal_default_options(void);
char **expand_address(char *input, normalize_options_t options, size_t *n);
void expansion_array_destroy(char **expansions, size_t n);
typedef struct address_parser_response {
    size_t num_components;
    char **components;
    char **labels;
} address_parser_response_t;
typedef struct address_parser_options {
    char *language;
    char *country;
} address_parser_options_t;
void address_parser_response_destroy(address_parser_response_t *self);
address_parser_options_t get_libpostal_address_parser_default_options(void);
address_parser_response_t *parse_address(char *address, address_parser_options_t options);
bool libpostal_setup(void);
void libpostal_teardown(void);
bool libpostal_setup_parser(void);
void libpostal_teardown_parser(void);
bool libpostal_setup_language_classifier(void);
void libpostal_teardown_language_classifier(void);
]]

local lib = ffi_load "postal"
local initialized = false
local char_p = ffi_typeof "char*[?]"
local char_t = ffi_typeof "char[?]"
local size_t = ffi_typeof "size_t[1]"

local postal = {}

function postal.setup()
    assert(lib.libpostal_setup() == true, "Failed to setup libpostal.")
    assert(lib.libpostal_setup_language_classifier() == true, "Failed to setup libpostal language classifier.")
    assert(lib.libpostal_setup_parser() == true, "Failed to setup libpostal parser.")
    initialized = true
end

function postal.teardown()
    lib.libpostal_teardown()
    lib.libpostal_teardown_language_classifier()
    lib.libpostal_teardown_parser()
    initialized = false
end

function postal.expand_address(address, options)
    if not initialized then
        postal.setup()
    end
    local o = lib.get_libpostal_default_options();
    if type(options) == "table" then
        local languages = options.languages
        if type(languages) == "table" then
            local l = #languages
            o.num_languages = l
            local x = ffi_new(char_p, l)
            for i = 1, l do
                x[i-1] = ffi_new(char_t, #languages[i], languages[i])
            end
            o.languages = x
        end
        if type(options.address_components)       == "number"  then o.address_components       = options.address_components       end
        if type(options.latin_ascii)              == "boolean" then o.latin_ascii              = options.latin_ascii              end
        if type(options.transliterate)            == "boolean" then o.transliterate            = options.transliterate            end
        if type(options.strip_accents)            == "boolean" then o.strip_accents            = options.strip_accents            end
        if type(options.decompose)                == "boolean" then o.decompose                = options.decompose                end
        if type(options.lowercase)                == "boolean" then o.lowercase                = options.lowercase                end
        if type(options.trim_string)              == "boolean" then o.trim_string              = options.trim_string              end
        if type(options.drop_parentheticals)      == "boolean" then o.drop_parentheticals      = options.drop_parentheticals      end
        if type(options.replace_numeric_hyphens)  == "boolean" then o.replace_numeric_hyphens  = options.replace_numeric_hyphens  end
        if type(options.delete_numeric_hyphens)   == "boolean" then o.delete_numeric_hyphens   = options.delete_numeric_hyphens   end
        if type(options.split_alpha_from_numeric) == "boolean" then o.split_alpha_from_numeric = options.split_alpha_from_numeric end
        if type(options.replace_word_hyphens)     == "boolean" then o.replace_word_hyphens     = options.replace_word_hyphens     end
        if type(options.delete_word_hyphens)      == "boolean" then o.delete_word_hyphens      = options.delete_word_hyphens      end
        if type(options.delete_final_periods)     == "boolean" then o.delete_final_periods     = options.delete_final_periods     end
        if type(options.delete_acronym_periods)   == "boolean" then o.delete_acronym_periods   = options.delete_acronym_periods   end
        if type(options.drop_english_possessives) == "boolean" then o.drop_english_possessives = options.drop_english_possessives end
        if type(options.delete_apostrophes)       == "boolean" then o.delete_apostrophes       = options.delete_apostrophes       end
        if type(options.expand_numex)             == "boolean" then o.expand_numex             = options.expand_numex             end
        if type(options.roman_numerals)           == "boolean" then o.roman_numerals           = options.roman_numerals           end
    end
    local c = ffi_new(char_t, #address + 1, address)
    local s = ffi_new(size_t)
    local e = ffi_gc(lib.expand_address(c, o, s), lib.expansion_array_destroy)
    local i = -1
    return function()
        i = i + 1
        if i < s[0] then return ffi_string(e[i]) end
    end
end

function postal.parse_address(address, language, country)
    if not initialized then
        postal.setup()
    end
    if type(language) == "table" then
        if language.language then
            language = language.language
        end
        if language.country then
            country = language.country
        end
    end
    local o = lib.get_libpostal_address_parser_default_options();
    if language then
        o.language = ffi_new(char_t, #language + 1, language)
    else
    end
    if country then
        o.country = ffi_new(char_t, #country + 1, country)
    end
    local c = ffi_new(char_t, #address + 1, address)
    local p = ffi_gc(lib.parse_address(c, o), lib.address_parser_response_destroy)
    local l = tonumber(p.num_components) - 1
    local r = {}
    for i = 0, l do
        r[ffi_string(p.labels[i])] = ffi_string(p.components[i])
    end
    return r
end

return postal