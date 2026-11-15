# Nyra command-line arguments

`args` provides a reusable `ArgParser` for GNU and POSIX-style command lines.
It is implemented in Nyra and uses the hosted standard library.

```nyra
import "stdlib:stdlib.ny";
import "args:args.ny";

func main(argv: ref <string>[]) -> int32 {
  var parser = ArgParser.New();
  let verbose = parser.AddFlag("verbose", settings: ArgOptionSettings{
    abbreviation: "v", help: "Print the selected format"
  });
  let format = parser.AddOption("format", settings: ArgOptionSettings{
    abbreviation: "f", value_help: "name", help: "Choose an output format"
  }, default_value: "text");
  if verbose.IsErr() || format.IsErr() {
    return 2;
  }

  let parsed = parser.ParseArgv(argv);
  if parsed.IsErr() {
    Console.Eprintln(parsed.get_if<ArgError>()!.message);
    Console.Eprint(parser.Usage());
    return 2;
  }

  let result = parsed.get_if<ArgResults>()!;
  if result.Flag("verbose")! {
    Console.Println(result.Option("format")!);
  }
  Console.Println(result.Rest().Join(","));
  return 0;
}
```

Running the example as `app -vf=json input.ny -- --literal` prints
`json` and then `input.ny,--literal`.

- Use `ParseArgv` for Nyra's `main` array, which includes the executable name.
  Use `Parse` for a token array that already starts with the first argument.
- Register flags with `AddFlag`. Flags can accept `--no-name`; abbreviations
  may be grouped. Register single values with `AddOption` and use
  `--name=value`, `--name value`, `-nvalue`, `-n=value` or `-n value`.
  A grouped short argument can end in a value option.
- `AddMultiOption` collects repeated values in order and can split commas.
  An explicit occurrence replaces defaults. Set `allowed` to constrain
  values and `required` to require an occurrence during parsing.
- `--` ends option and command recognition. A lone `-` is positional.
  An option awaiting its value can consume a token such as `-42`; use an
  attached value to supply a literal `--`. Set
  `allow_trailing_options: false` to stop at the first positional token.
- Configure another parser and pass it to `AddCommand`. The child can have
  its own commands. After command selection, options resolve from the
  current command outward to its parents. Use `Command()` to access the
  selected child result.
- Read values by their registered names. Use `WasParsed` to distinguish an
  explicit occurrence from a default. `ArgError` identifies the failure
  kind, input index, option and command. `Usage()` renders visible options
  and immediate child commands for the parser.

Use `ArgToken.At(argv, index)` for ordered grammars that apply options as
they encounter them. `Raw()` preserves exact spellings such as `-O2`.
`Matches("--name")` accepts the exact name or the `--name=value` spelling.
`HasValue()` distinguishes a missing operand from an explicitly empty one.
`Value()` reads an attached operand or the following argv entry, and
`AfterValue()` gives the index at which to resume. Use `IsDelimiter()`
when an invocation forwards the rest of argv to another program.

Run the package suite with `nyrac test .` from a standalone checkout.
From the NyraLang checkout, run `nyrac --workspace workspace.yaml test third_party/args`.
