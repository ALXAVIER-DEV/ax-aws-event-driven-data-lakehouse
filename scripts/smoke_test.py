import argparse
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALID_ENVIRONMENTS = ("dev", "hom", "prod")


def run(command: list[str]) -> int:
    print(f"Running: {' '.join(command)}")
    completed = subprocess.run(command, cwd=ROOT, check=False)
    return completed.returncode


def ensure_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Required file not found: {path}")


def validate_environment_files(environment: str) -> None:
    backend_file = ROOT / "environments" / environment / "backend.hcl"
    ensure_file(backend_file)


def validate_var_file(environment: str, var_file: Path) -> None:
    ensure_file(var_file)

    tfvars_content = var_file.read_text()
    if re.search(rf'environment\s*=\s*"{environment}"', tfvars_content) is None:
        raise ValueError(
            f"File {var_file} does not declare environment {environment!r}."
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run static or plan smoke tests for a target environment.")
    parser.add_argument("--environment", required=True, choices=VALID_ENVIRONMENTS)
    parser.add_argument(
        "--mode",
        default="static",
        choices=("static", "plan"),
        help="Use 'static' for local checks only or 'plan' to run terraform init/plan against the environment backend.",
    )
    parser.add_argument(
        "--var-file",
        default=None,
        help="Optional tfvars file path. Defaults to <environment>.tfvars in the repository root.",
    )
    args = parser.parse_args()

    validate_environment_files(args.environment)
    if args.var_file is not None:
        var_file = ROOT / args.var_file
    else:
        default_var_file = ROOT / f"{args.environment}.tfvars"
        fallback_var_file = ROOT / f"{args.environment}.tfvars.example"
        var_file = default_var_file if default_var_file.exists() else fallback_var_file

    validate_var_file(args.environment, var_file)

    commands = [
        ["terraform", "fmt", "-check", "-recursive"],
        ["terraform", "init", "-backend=false"],
        ["terraform", "validate"],
        [sys.executable, "-m", "compileall", "lambda_src", "glue_src", "tests"],
        [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"],
    ]

    if args.mode == "plan":
        commands.extend(
            [
                [
                    "terraform",
                    "init",
                    "-reconfigure",
                    f"-backend-config=environments/{args.environment}/backend.hcl",
                ],
                [
                    "terraform",
                    "plan",
                    "-lock=false",
                    "-input=false",
                    f"-var-file={var_file.relative_to(ROOT)}",
                ],
            ]
        )

    for command in commands:
        exit_code = run(command)
        if exit_code != 0:
            return exit_code

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
