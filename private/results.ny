// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of CommandLineArguments;

struct ArgValue {
  name: string;
  kind: ArgOptionKind;
  parsed: bool;
  flag: bool;
  value: string?;
  values: Array<string>;
}

// A parse owns its values and positional tokens independently of its schema.
struct ArgResultScope {
  scope_id: int32;
  name: string;
  options: Array<ArgValue>;
  rest: Array<string>;
}

/** @brief A view of one scope in an owned result. */
pub struct ArgResults {
  scopes: Array<ArgResultScope>;
  level: int32;
}

pub method(ArgResults) Name() -> string {
  if self.scopes.IsEmpty() {
    return "";
  }

  return self.scopes.Get(self.level).name;
}

pub method(ArgResults) Command() -> ArgResults? {
  let next = self.level + 1;
  if next >= self.scopes.Len() {
    return nil;
  }

  return ArgResults{scopes: self.scopes, level: next};
}

pub method(ArgResults) Rest() -> Array<string> {
  if self.scopes.IsEmpty() {
    return Array<string>.New();
  }

  return self.scopes.Get(self.level).rest;
}

pub method(ArgResults) WasParsed(name: ref string) -> bool {
  let option = self.Find(name);
  return option != nil && option!.parsed;
}

pub method(ArgResults) Flag(name: ref string) -> bool? {
  let option = self.Find(name);
  if option == nil || option!.kind != ArgOptionKind.Flag {
    return nil;
  }

  return option!.flag;
}

pub method(ArgResults) Option(name: ref string) -> string? {
  let option = self.Find(name);
  if option == nil || option!.kind != ArgOptionKind.Option {
    return nil;
  }

  return option!.value;
}

pub method(ArgResults) MultiOption(name: ref string) -> Array<string>? {
  let option = self.Find(name);
  if option == nil || option!.kind != ArgOptionKind.Multi {
    return nil;
  }

  return option!.values;
}

method(ArgResults) Find(name: ref string) -> ArgValue? {
  if self.scopes.IsEmpty() {
    return nil;
  }

  let options = self.scopes.Get(self.level).options;
  var index: int32 = 0;
  while index < options.Len() {
    let option = options.Get(index);
    if option.name == name {
      return option;
    }

    index += 1;
  }

  return nil;
}

static method(ArgResultScope) New(scope_id: int32, definition: ref ArgScope) -> ArgResultScope {
  var options = Array<ArgValue>.New();
  var index: int32 = 0;
  while index < definition.options.Len() {
    let option = definition.options.Get(index);
    options.Push(ArgValue{
      name: option.name, kind: option.kind, flag: option.default_flag,
      value: option.default_value, values: option.defaults
    });
    index += 1;
  }

  return ArgResultScope{scope_id: scope_id, name: definition.name, options: options, rest: Array<string>.New()};
}

// Only the successful parse can publish these mutations and their owned strings.
method(ArgValue) SetText(definition: ref ArgDefinition, text: ref string) -> bool {
  if self.kind == ArgOptionKind.Option {
    if !definition.Accepts(text) {
      return false;
    }

    self.value = copy(text);
  } else {
    if !self.parsed {
      self.values = Array<string>.New();
    }

    var start: int32 = 0;
    var end: int32 = 0;
    while end < text.length && definition.split_commas {
      if text[end] == ',' {
        if !self.AppendValue(definition, text.View(start, end - start)) {
          return false;
        }

        start = end + 1;
      }

      end += 1;
    }
    if !self.AppendValue(definition, text.View(start, text.length - start)) {
      return false;
    }
  }

  self.parsed = true;
  return true;
}

method(ArgValue) AppendValue(definition: ref ArgDefinition, value: ref string) -> bool {
  if !definition.Accepts(value) {
    return false;
  }

  self.values.Push(copy(value));
  return true;
}
