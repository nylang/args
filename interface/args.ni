// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "stdlib:stdlib.ny";

/** @brief Definition or command-line parsing failure. */
pub enum ArgErrorKind {
  InvalidDefinition,
  DuplicateName,
  InvalidStart,
  UnknownOption,
  MissingValue,
  UnexpectedValue,
  InvalidValue,
  MissingOption
}

/** @brief Error and its zero-based input index. Definition and missing-option errors use -1. */
pub struct ArgError {
  kind: ArgErrorKind;
  index: int32;
  option: string;
  command: string;
  message: string;
}

/** @brief Shared names, usage text and optional value constraints for an option.
 * @note An empty allowed list accepts any value. Flags use abbreviation, help, aliases and hidden. */
pub struct ArgOptionSettings {
  abbreviation: string;
  help: string;
  value_help: string;
  aliases: Array<string>;
  allowed: Array<string>;
  hidden: bool;
}

/** @brief One token and its lookahead for an ordered command-line grammar.
 * @note Use this for grammars that apply each occurrence immediately or have context-specific spellings. */
pub struct ArgToken;

/** @brief Read an in-range token and its optional successor.
 * @note The snapshot retains managed strings. External argv bytes must outlive the snapshot and its views. */
pub static method(ArgToken) At(arguments: ref <string>[], index: int32) -> ArgToken;

/** @brief Return the original spelling, including any attached value. */
pub method(ArgToken) Raw() -> string;

/** @brief Return the zero-based index of this token in the input array. */
pub method(ArgToken) Index() -> int32;

/** @brief Return the spelling before the first equals sign. */
pub method(ArgToken) Name() -> string;

/** @brief Check for a hyphen-prefixed option or delimiter.
 * @note A single hyphen is positional unless bare_dash is enabled. */
pub method(ArgToken) IsOption({ bare_dash: bool = false }) -> bool;

/** @brief Check for the exact end-of-options marker. */
pub method(ArgToken) IsDelimiter() -> bool;

/** @brief Match a spelling with an optional equals-delimited value. */
pub method(ArgToken) Matches(spelling: ref string) -> bool;

/** @brief Report whether an equals sign supplies a value, including an empty one. */
pub method(ArgToken) HasAttachedValue() -> bool;

/** @brief Report whether there is another argv token, regardless of its spelling. */
pub method(ArgToken) HasFollowing() -> bool;

/** @brief Report whether an attached value or a following token is present.
 * @note The caller chooses whether a following delimiter is a valid operand. */
pub method(ArgToken) HasValue() -> bool;

/** @brief Return the attached value or following token, or empty text when neither exists. */
pub method(ArgToken) Value() -> string;

/** @brief Return the first unconsumed index after an option with a present value. */
pub method(ArgToken) AfterValue() -> int32;

/** @brief Reusable definitions for a command line or subcommand. */
pub struct ArgParser;

/** @brief Create a parser. Set allow_trailing_options to false to stop at the first positional. */
pub static method(ArgParser) New({ allow_trailing_options: bool = true }) -> ArgParser;

/** @brief Register a boolean flag and, when enabled, its --no- spelling. */
pub method(ArgParser) AddFlag(
  name: ref string, {
    settings: ArgOptionSettings? = nil, default_value: bool = false, negatable: bool = true
  }
) -> Result<Unit, ArgError>;

/** @brief Register a single-value option. The last supplied value wins.
 * @note Required options must appear on the command line. */
pub method(ArgParser) AddOption(
  name: ref string, {
    settings: ArgOptionSettings? = nil, default_value: string? = nil, required: bool = false
  }
) -> Result<Unit, ArgError>;

/** @brief Register an option whose occurrences append values in input order.
 * @note Explicit occurrences replace defaults. Comma splitting is enabled by default. */
pub method(ArgParser) AddMultiOption(
  name: ref string, {
    settings: ArgOptionSettings? = nil, defaults: Array<string>? = nil,
    split_commas: bool = true, required: bool = false
  }
) -> Result<Unit, ArgError>;

/** @brief Register a snapshot of a configured parser as a child command. */
pub method(ArgParser) AddCommand(
  name: ref string, command: ref ArgParser, { help: string = "" }
) -> Result<Unit, ArgError>;

/** @brief Parse argument tokens starting at the supplied zero-based index.
 * @note Returns owned values and leaves the definitions reusable. */
pub method(ArgParser) Parse(
  arguments: ref <string>[], { start: int32 = 0 }
) -> Result<ArgResults, ArgError>;

/** @brief Parse the array passed to Nyra main, skipping the executable name when present. */
pub method(ArgParser) ParseArgv(arguments: ref <string>[]) -> Result<ArgResults, ArgError>;

/** @brief Format the visible options and immediate child commands for this parser. */
pub method(ArgParser) Usage() -> string;

/** @brief Owns the parsed values for one selected command scope.
 * @note Named queries use the canonical name registered with AddFlag or AddOption. */
pub struct ArgResults;

/** @brief Return the selected scope's name, or an empty name for the root. */
pub method(ArgResults) Name() -> string;

/** @brief Return the selected child command and its values, or nil. */
pub method(ArgResults) Command() -> ArgResults?;

/** @brief Return positional tokens for this scope in input order. */
pub method(ArgResults) Rest() -> Array<string>;

/** @brief Report whether this scope explicitly received the named option or flag. */
pub method(ArgResults) WasParsed(name: ref string) -> bool;

/** @brief Return a parsed or default flag. An unknown name or wrong kind returns nil. */
pub method(ArgResults) Flag(name: ref string) -> bool?;

/** @brief Return a parsed or default single value, or nil if unavailable. */
pub method(ArgResults) Option(name: ref string) -> string?;

/** @brief Return the parsed list or defaults. An unknown name or wrong kind returns nil. */
pub method(ArgResults) MultiOption(name: ref string) -> Array<string>?;
