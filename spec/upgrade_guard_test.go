package spec_test

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// The pre-deploy hook refuses to upgrade a deployed RabbitMQ older than 3.13.
// The testkit never runs a deploy, so it cannot reach that hook. These cases
// instead run the hook's decision functions through a small Perl driver, with
// the manifest BOSH would report supplied as a fixture.
type guardResult struct {
	Name    string `json:"name"`
	OK      bool   `json:"ok"`
	Message string `json:"message"`
}

var _ = Describe("Upgrade guard", func() {
	It("decides every case in the fixtures as expected", func() {
		guardDir := filepath.Join(KitDir, "spec", "upgrade-guard")

		cmd := exec.Command("perl",
			filepath.Join(guardDir, "driver.pl"),
			KitDir,
			filepath.Join(guardDir, "cases.yml"))
		cmd.Env = os.Environ()
		var stderr []byte
		out, err := cmd.Output()
		if exitErr, ok := err.(*exec.ExitError); ok {
			stderr = exitErr.Stderr
		}
		Expect(err).ToNot(HaveOccurred(), "driver failed: %s", string(stderr))

		var results []guardResult
		Expect(json.Unmarshal(out, &results)).To(Succeed())
		Expect(len(results)).To(BeNumerically(">=", 25), "the driver ran fewer cases than the fixtures define")

		for _, r := range results {
			Expect(r.OK).To(BeTrue(), "%s: %s", r.Name, r.Message)
		}
	})
})
