// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "stdlib:stdlib.ny";
import "ntest:ntest.ny";
import "args.ny";

@test
func test_flags_aliases_and_long_and_short_values() {
  var parser = ArgParser.New();
  var aliases = Array<string>.New();
  aliases.Push("chatty");
  AssertTrue(parser.AddFlag("verbose", settings: ArgOptionSettings{abbreviation: "v", aliases: aliases}).IsOk());
  AssertTrue(parser.AddFlag("quiet", settings: ArgOptionSettings{abbreviation: "q"}, negatable: false).IsOk());
  AssertTrue(parser.AddOption("format", settings: ArgOptionSettings{abbreviation: "f"}).IsOk());
  let tokens: <string>[7] = {"-vqfjson", "file", "--no-chatty", "--format", "text", "-f=yaml", "-"};
  let parsed = parser.Parse(tokens);
  if AssertTrue(parsed.IsOk()) != 0 {
    return;
  }

  let result = parsed.get_if<ArgResults>()!;
  AssertTrue(!result.Flag("verbose")! && result.WasParsed("verbose"));
  AssertTrue(result.Flag("quiet")!);
  AssertEqString(result.Option("format")!, "yaml");
  AssertTrue(result.Flag("format") == nil && result.MultiOption("missing") == nil);
  let rest = result.Rest();
  AssertEqI32(rest.Len(), 2);
  AssertEqString(rest.Get(0), "file");
  AssertEqString(rest.Get(1), "-");
}

@test
func test_defaults_allowed_values_and_explicit_empty() {
  var parser = ArgParser.New();
  var allowed = Array<string>.New();
  allowed.Push("on");
  allowed.Push("");
  AssertTrue(parser.AddOption("mode",
    settings: ArgOptionSettings{allowed: allowed}, default_value: "on").IsOk());
  AssertTrue(parser.AddFlag("color", default_value: true).IsOk());
  let empty: <string>[0] = <string>[0]{};
  let baseline = parser.ParseArgv(empty);
  if AssertTrue(baseline.IsOk()) != 0 {
    return;
  }

  let defaults = baseline.get_if<ArgResults>()!;
  AssertTrue(defaults.Flag("color")! && !defaults.WasParsed("color"));
  AssertEqString(defaults.Option("mode")!, "on");
  AssertTrue(!defaults.WasParsed("mode"));

  let argv: <string>[3] = {"app", "--mode=", "--no-color"};
  let explicit = parser.ParseArgv(argv);
  if AssertTrue(explicit.IsOk()) != 0 {
    return;
  }

  let result = explicit.get_if<ArgResults>()!;
  AssertTrue(!result.Flag("color")! && result.WasParsed("mode"));
  AssertEqString(result.Option("mode")!, "");
  AssertEqI32(result.Rest().Len(), 0);
  AssertEqString(defaults.Option("mode")!, "on");
}

@test
func test_multi_options_replace_defaults_and_preserve_order() {
  var parser = ArgParser.New();
  var defaults = Array<string>.New();
  defaults.Push("old");
  AssertTrue(parser.AddMultiOption("tag", settings: ArgOptionSettings{abbreviation: "t"}, defaults: defaults).IsOk());
  AssertTrue(parser.AddMultiOption("include",
    settings: ArgOptionSettings{abbreviation: "I"}, split_commas: false).IsOk());
  let tokens: <string>[5] = {"--tag=red,blue", "-t", "green,,", "-Ipath,part", "--include=雪"};
  let parsed = parser.Parse(tokens);
  if AssertTrue(parsed.IsOk()) != 0 {
    return;
  }

  let result = parsed.get_if<ArgResults>()!;
  AssertEqString(result.MultiOption("tag")!.Join("|"), "red|blue|green||");
  AssertEqString(result.MultiOption("include")!.Join("|"), "path,part|雪");
  let empty: <string>[0] = <string>[0]{};
  let baseline = parser.Parse(empty);
  if AssertTrue(baseline.IsOk()) != 0 {
    return;
  }

  AssertEqString(baseline.get_if<ArgResults>()!.MultiOption("tag")!.Join("|"), "old");
}

@test
func test_nested_commands_resolve_options_from_the_nearest_scope() {
  var leaf = ArgParser.New();
  AssertTrue(leaf.AddOption("mode", required: true).IsOk());
  AssertTrue(leaf.AddFlag("verbose", settings: ArgOptionSettings{abbreviation: "v"}).IsOk());
  var build = ArgParser.New();
  AssertTrue(build.AddCommand("check", leaf).IsOk());
  var root = ArgParser.New();
  AssertTrue(root.AddFlag("verbose", settings: ArgOptionSettings{abbreviation: "v"}).IsOk());
  AssertTrue(root.AddFlag("debug", settings: ArgOptionSettings{abbreviation: "d"}).IsOk());
  AssertTrue(root.AddOption("mode").IsOk());
  AssertTrue(root.AddCommand("build", build).IsOk());
  AssertTrue(build.AddFlag("late").IsOk());

  let tokens: <string>[8] = {"--mode=root", "build", "check", "-vd", "--mode", "strict", "src.ny", "--"};
  let parsed = root.Parse(tokens);
  if AssertTrue(parsed.IsOk()) != 0 {
    return;
  }

  let top = parsed.get_if<ArgResults>()!;
  AssertEqString(top.Name(), "");
  AssertTrue(!top.Flag("verbose")! && top.Flag("debug")!);
  AssertEqString(top.Option("mode")!, "root");
  let middle = top.Command()!;
  let bottom = middle.Command()!;
  AssertEqString(middle.Name(), "build");
  AssertEqString(bottom.Name(), "check");
  AssertEqString(bottom.Option("mode")!, "strict");
  AssertTrue(bottom.Flag("verbose")! && bottom.Command() == nil);
  AssertEqString(bottom.Rest().Join("|"), "src.ny");

  let missing: <string>[2] = {"build", "check"};
  let missing_result = root.Parse(missing);
  if AssertTrue(missing_result.IsErr()) != 0 {
    return;
  }

  let error = missing_result.get_if<ArgError>()!;
  AssertTrue(error.kind == ArgErrorKind.MissingOption && error.index == -1);
  AssertEqString(error.option, "mode");
  AssertEqString(error.command, "check");
  let late: <string>[2] = {"build", "--late"};
  check_parse_error(root.Parse(late), ArgErrorKind.UnknownOption, 1);
}

@test
func test_end_marker_and_trailing_options() {
  var parser = ArgParser.New();
  AssertTrue(parser.AddOption("number", settings: ArgOptionSettings{abbreviation: "n"}).IsOk());
  let tokens: <string>[5] = {"input", "-n", "-12", "--", "--literal"};
  let parsed = parser.Parse(tokens);
  if AssertTrue(parsed.IsOk()) != 0 {
    return;
  }

  let result = parsed.get_if<ArgResults>()!;
  AssertEqString(result.Option("number")!, "-12");
  AssertEqString(result.Rest().Join("|"), "input|--literal");

  var strict = ArgParser.New(allow_trailing_options: false);
  AssertTrue(strict.AddFlag("verbose").IsOk());
  AssertTrue(strict.AddCommand("build", ArgParser.New()).IsOk());
  let literal: <string>[4] = {"input", "build", "--verbose", "--"};
  let untouched = strict.Parse(literal);
  if AssertTrue(untouched.IsOk()) != 0 {
    return;
  }

  let positional = untouched.get_if<ArgResults>()!;
  AssertTrue(!positional.Flag("verbose")! && positional.Command() == nil);
  AssertEqString(positional.Rest().Join("|"), "input|build|--verbose|--");
}

@test
func test_structured_errors_and_atomic_registration() {
  var parser = ArgParser.New();
  AssertTrue(parser.AddFlag("color", settings: ArgOptionSettings{abbreviation: "c"}).IsOk());
  AssertTrue(parser.AddOption("no-color").IsErr());
  AssertTrue(parser.AddFlag("new", settings: ArgOptionSettings{abbreviation: "c"}).IsErr());
  AssertTrue(parser.AddFlag("new", settings: ArgOptionSettings{abbreviation: "n"}).IsOk());
  AssertTrue(parser.AddOption("--bad").IsErr());
  var allowed = Array<string>.New();
  allowed.Push("debug");
  let settings = ArgOptionSettings{allowed: allowed};
  AssertTrue(parser.AddOption("mode", settings: settings, default_value: "other").IsErr());
  AssertTrue(parser.AddOption("mode", settings: settings).IsOk());

  let unknown: <string>[1] = {"--missing"};
  let missing: <string>[2] = {"--mode", "--"};
  let unexpected: <string>[1] = {"-c=true"};
  let invalid: <string>[1] = {"--mode=release"};
  let unicode_short: <string>[1] = {"-雪"};
  check_parse_error(parser.Parse(unknown), ArgErrorKind.UnknownOption, 0);
  check_parse_error(parser.Parse(missing), ArgErrorKind.MissingValue, 0);
  check_parse_error(parser.Parse(unexpected), ArgErrorKind.UnexpectedValue, 0);
  check_parse_error(parser.Parse(invalid), ArgErrorKind.InvalidValue, 0);
  check_parse_error(parser.Parse(unicode_short), ArgErrorKind.UnknownOption, 0);
  check_parse_error(parser.Parse(unknown, start: 2), ArgErrorKind.InvalidStart, 2);
  let valid: <string>[2] = {"--mode=debug", "-n"};
  let parsed = parser.Parse(valid);
  if AssertTrue(parsed.IsOk()) != 0 {
    return;
  }

  let result = parsed.get_if<ArgResults>()!;
  AssertTrue(result.Flag("new")! && !result.WasParsed("color"));
  AssertEqString(result.Option("mode")!, "debug");
}

// nyra-lint-allow: prefer-type-owned-functions -- Shares assertions across distinct parser failures.
func check_parse_error(parsed: Result<ArgResults, ArgError>, kind: ArgErrorKind, index: int32) -> void {
  if AssertTrue(parsed.IsErr()) != 0 {
    return;
  }

  let error = parsed.get_if<ArgError>()!;
  AssertTrue(error.kind == kind && error.index == index && error.message.length > 0);
}

@test
func test_usage_describes_visible_options_and_commands() {
  var parser = ArgParser.New();
  AssertTrue(parser.AddFlag("color", settings: ArgOptionSettings{abbreviation: "c", help: "Use color"}).IsOk());
  AssertTrue(parser.AddOption("output",
    settings: ArgOptionSettings{value_help: "path"}, required: true).IsOk());
  AssertTrue(parser.AddFlag("internal", settings: ArgOptionSettings{hidden: true}).IsOk());
  AssertTrue(parser.AddCommand("run", ArgParser.New(), help: "Run the tool").IsOk());
  let usage = parser.Usage();
  AssertTrue(usage.Contains("-c, --[no-]color") && usage.Contains("Use color"));
  AssertTrue(usage.Contains("--output <path> (required)") && usage.Contains("run  Run the tool"));
  AssertTrue(!usage.Contains("internal"));
}
