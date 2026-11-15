// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of CommandLineArguments;

enum ArgOptionKind { Flag, Option, Multi }

// Each scope owns its definitions. Parent indices form a tree rooted at zero.
struct ArgScope {
  name: string;
  help: string;
  parent: int32;
  trailing: bool;
  options: Array<ArgDefinition>;
}

struct ArgDefinition {
  name: string;
  settings: ArgOptionSettings;
  spellings: Array<string>;
  positive_count: int32;
  kind: ArgOptionKind;
  default_flag: bool;
  default_value: string?;
  defaults: Array<string>;
  required: bool;
  negatable: bool;
  split_commas: bool;
}

/** @brief Owns definitions shared by read-only parse calls. */
pub struct ArgParser {
  scopes: Array<ArgScope>;
}

pub static method(ArgParser) New({ allow_trailing_options: bool = true }) -> ArgParser {
  var scopes = Array<ArgScope>.New();
  scopes.Push(ArgScope{parent: -1, trailing: allow_trailing_options, options: Array<ArgDefinition>.New()});

  return ArgParser{scopes: scopes};
}

pub method(ArgParser) AddFlag(
  name: ref string, {
    settings: ArgOptionSettings? = nil, default_value: bool = false, negatable: bool = true
  }
) -> Result<Unit, ArgError> {
  return self.AddDefinition(ArgDefinition{
    name: copy(name), settings: settings == nil ? ArgOptionSettings{} : settings!,
    kind: ArgOptionKind.Flag, default_flag: default_value, negatable: negatable
  });
}

pub method(ArgParser) AddOption(
  name: ref string, {
    settings: ArgOptionSettings? = nil, default_value: string? = nil, required: bool = false
  }
) -> Result<Unit, ArgError> {
  return self.AddDefinition(ArgDefinition{
    name: copy(name), settings: settings == nil ? ArgOptionSettings{} : settings!,
    kind: ArgOptionKind.Option, default_value: default_value, required: required
  });
}

pub method(ArgParser) AddMultiOption(
  name: ref string, {
    settings: ArgOptionSettings? = nil, defaults: Array<string>? = nil,
    split_commas: bool = true, required: bool = false
  }
) -> Result<Unit, ArgError> {
  return self.AddDefinition(ArgDefinition{
    name: copy(name), settings: settings == nil ? ArgOptionSettings{} : settings!, kind: ArgOptionKind.Multi,
    defaults: defaults == nil ? Array<string>.New() : defaults!,
    split_commas: split_commas, required: required
  });
}

method(ArgParser) AddDefinition(definition: ArgDefinition) -> Result<Unit, ArgError> {
  if self.scopes.IsEmpty() {
    return ArgDefinition.Error(ArgErrorKind.InvalidDefinition, definition.name, "create the parser with ArgParser.New");
  }
  if !ArgDefinition.ValidName(definition.name) || !ArgDefinition.ValidAbbreviation(definition.settings.abbreviation) {
    return ArgDefinition.Error(ArgErrorKind.InvalidDefinition, definition.name, "invalid option name or abbreviation");
  }

  var option = definition;
  option.spellings = Array<string>.New();
  option.spellings.Push(option.name);
  var index: int32 = 0;
  while index < option.settings.aliases.Len() {
    let alias: string = option.settings.aliases.Get(index);
    if !ArgDefinition.ValidName(alias) {
      return ArgDefinition.Error(ArgErrorKind.InvalidDefinition, alias, "invalid option alias");
    }
    if option.LongIndex(alias) >= 0 {
      return ArgDefinition.Error(ArgErrorKind.DuplicateName, alias, "duplicate option alias");
    }

    option.spellings.Push(copy(alias));
    index += 1;
  }

  option.positive_count = option.spellings.Len();
  if option.negatable {
    index = 0;
    while index < option.positive_count {
      let negation = "no-".Concat(option.spellings.Get(index));
      if option.LongIndex(negation) >= 0 {
        return ArgDefinition.Error(ArgErrorKind.DuplicateName, negation, "alias conflicts with flag negation");
      }

      option.spellings.Push(negation);
      index += 1;
    }
  }

  if !option.ValidDefaults() {
    return ArgDefinition.Error(ArgErrorKind.InvalidDefinition, option.name, "option default is outside its allowed values");
  }

  let root = self.scopes.Get(0);
  index = 0;
  while index < option.spellings.Len() {
    let spelling: string = option.spellings.Get(index);
    if root.FindLong(spelling).index >= 0 {
      return ArgDefinition.Error(ArgErrorKind.DuplicateName, spelling, "option spelling is already registered");
    }

    index += 1;
  }

  let abbreviation = option.settings.abbreviation;
  if abbreviation.length > 0 && root.FindShort(abbreviation[0]) >= 0 {
    return ArgDefinition.Error(ArgErrorKind.DuplicateName, abbreviation, "abbreviation is already registered");
  }

  self.scopes.GetMut(0).options.Push(option);
  return UnitValue();
}

pub method(ArgParser) AddCommand(
  name: ref string, command: ref ArgParser, { help: string = "" }
) -> Result<Unit, ArgError> {
  if self.scopes.IsEmpty() || command.scopes.IsEmpty() || !ArgDefinition.ValidName(name) {
    return ArgDefinition.Error(ArgErrorKind.InvalidDefinition, name, "invalid command name or uninitialized parser");
  }
  if self.FindCommand(0, name) >= 0 {
    return ArgDefinition.Error(ArgErrorKind.DuplicateName, name, "command is already registered");
  }

  // Copy the scope table and rebase parent indices. Child option arrays retain value semantics.
  let child: Array<ArgScope> = command.scopes;
  let offset = self.scopes.Len();
  var root: ArgScope = child.Get(0);
  root.name = copy(name);
  root.help = copy(help);
  root.parent = 0;
  self.scopes.Push(root);
  var index: int32 = 1;
  while index < child.Len() {
    var entry: ArgScope = child.Get(index);
    entry.parent += offset;
    self.scopes.Push(entry);
    index += 1;
  }

  return UnitValue();
}

method(ArgParser) FindCommand(parent: int32, name: ref string) -> int32 {
  var index = parent + 1;
  while index < self.scopes.Len() {
    let command = self.scopes.Get(index);
    if command.parent == parent && command.name == name {
      return index;
    }

    index += 1;
  }

  return -1;
}

struct ArgLongMatch {
  index: int32;
  negated: bool;
}

method(ArgScope) FindLong(name: ref string) -> ArgLongMatch {
  var index: int32 = 0;
  while index < self.options.Len() {
    let option = self.options.Get(index);
    let spelling = option.LongIndex(name);
    if spelling >= 0 {
      return ArgLongMatch{index: index, negated: spelling >= option.positive_count};
    }

    index += 1;
  }

  return ArgLongMatch{index: -1};
}

method(ArgScope) FindShort(letter: uint8) -> int32 {
  var index: int32 = 0;
  while index < self.options.Len() {
    let abbreviation = self.options.Get(index).settings.abbreviation;
    if abbreviation.length != 0 && abbreviation[0] == letter {
      return index;
    }

    index += 1;
  }

  return -1;
}

method(ArgDefinition) LongIndex(name: ref string) -> int32 {
  var index: int32 = 0;
  while index < self.spellings.Len() {
    if self.spellings.Get(index) == name {
      return index;
    }

    index += 1;
  }

  return -1;
}

method(ArgDefinition) Accepts(value: ref string) -> bool {
  if self.settings.allowed.IsEmpty() {
    return true;
  }

  var index: int32 = 0;
  while index < self.settings.allowed.Len() {
    if self.settings.allowed.Get(index) == value {
      return true;
    }

    index += 1;
  }

  return false;
}

method(ArgDefinition) ValidDefaults() -> bool {
  if self.default_value != nil && !self.Accepts(self.default_value!) {
    return false;
  }

  var index: int32 = 0;
  while index < self.defaults.Len() {
    if !self.Accepts(self.defaults.Get(index)) {
      return false;
    }

    index += 1;
  }

  return true;
}

static method(ArgDefinition) IsLetterOrDigit(byte: uint8) -> bool {
  return (byte >= 'a' && byte <= 'z') || (byte >= 'A' && byte <= 'Z') || (byte >= '0' && byte <= '9');
}

static method(ArgDefinition) ValidName(name: ref string) -> bool {
  if name.length == 0 || !ArgDefinition.IsLetterOrDigit(name[0]) {
    return false;
  }

  var index: int32 = 1;
  while index < name.length {
    let byte: uint8 = name[index];
    if !ArgDefinition.IsLetterOrDigit(byte) && byte != '-' && byte != '_' {
      return false;
    }

    index += 1;
  }

  return true;
}

static method(ArgDefinition) ValidAbbreviation(name: ref string) -> bool {
  return name.length == 0 || (name.length == 1 && ArgDefinition.IsLetterOrDigit(name[0]));
}

static method(ArgDefinition) Error(kind: ArgErrorKind, name: ref string, message: ref string) -> ArgError {
  return ArgError{kind: kind, index: -1, option: copy(name), message: copy(message)};
}
