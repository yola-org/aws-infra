import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("public_config", Path(__file__).parents[1] / "run-with-public-config.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PublicConfigTest(unittest.TestCase):
    path = "/vestio/dev"

    def test_shared_root_and_optimizer_namespace(self):
        for environment in ("dev", "prod"):
            for service in ("backend", "frontend"):
                self.assertEqual(module.parameter_path(environment, service), f"/vestio/{environment}")
            self.assertEqual(module.parameter_path(environment, "image-optimizer"), f"/vestio/{environment}/image-optimizer")

    def parameter(self, name="AWS_REGION", kind="String", value="ca-central-1"):
        return {"Name": self.path + "/" + name, "Type": kind, "Value": value}

    def test_preserves_values_without_shell_interpretation(self):
        value = "literal $(command) `text` with spaces"
        self.assertEqual(module.load_environment([self.parameter(value=value)], self.path), {"AWS_REGION": value})

    def test_rejects_secret_parameters(self):
        with self.assertRaises(ValueError):
            module.load_environment([self.parameter(kind="SecureString")], self.path)

    def test_rejects_other_paths_and_nested_names(self):
        for name in ["/vestio/prod/AWS_REGION", self.path + "/image-optimizer/BUCKET_NAME", self.path + "/BAD-NAME"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                module.load_environment([{"Name": name, "Type": "String", "Value": "x"}], self.path)

    def test_rejects_empty_results_and_duplicates(self):
        for parameters in [[], [self.parameter(), self.parameter()]]:
            with self.assertRaises(ValueError):
                module.load_environment(parameters, self.path)


if __name__ == "__main__":
    unittest.main()
