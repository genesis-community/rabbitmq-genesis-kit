package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("RabbitMQ Kit", func() {

	Describe("RabbitMQ", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "base-certs",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("7 added/0 skipped/0 errors"),
			},
		})
		Test(Environment{
			Name:        "base-allparams",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "broker",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "broker-policy",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "no-rmq-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "no-mgmt-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "metrics-emitter",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "external-rmq-lb",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "route-registrar",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "nats-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "no-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "stomp",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "mqtt",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "prometheus",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			// Focus:       true,
		})
		Test(Environment{
			Name:        "all-plugins",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "prometheus-no-mgmt-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})

	})

	Describe("ignored settings", func() {
		Test(Environment{
			Name:        "ha-sync-mode",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisCheck:    ContainSubstring("ignored"),
				GenesisManifest: ContainSubstring("ignored"),
			},
		})
		Test(Environment{
			Name:        "no-prometheus-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisCheck:    ContainSubstring("effect"),
				GenesisManifest: ContainSubstring("effect"),
			},
		})
	})

	Describe("provided certificates", func() {
		Test(Environment{
			Name:        "provided-mgmt-cert",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "provided-mgmt-cert-no-rmq-tls",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
	})

	Describe("resolute", func() {
		Test(Environment{
			Name:        "resolute",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "resolute-mqtt-stomp",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "resolute-prometheus",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "resolute-wrong-stemcell-os",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("stemcell os to"),
				GenesisCheck:      ContainSubstring("stemcell os to"),
				GenesisManifest:   ContainSubstring("stemcell os to"),
			},
		})
		Test(Environment{
			Name:        "resolute-stemcell-without-feature",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("Enable the feature and remove that parameter"),
				GenesisCheck:      ContainSubstring("Enable the feature and remove that parameter"),
				GenesisManifest:   ContainSubstring("Enable the feature and remove that parameter"),
			},
		})
		Test(Environment{
			Name:        "resolute-broker",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "resolute-metrics-emitter",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("cannot be combined with"),
				GenesisCheck:      ContainSubstring("cannot be combined with"),
				GenesisManifest:   ContainSubstring("cannot be combined with"),
			},
		})
		Test(Environment{
			Name:        "resolute-route-registrar",
			CloudConfig: "aws",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("cannot be combined with"),
				GenesisCheck:      ContainSubstring("cannot be combined with"),
				GenesisManifest:   ContainSubstring("cannot be combined with"),
			},
		})
	})

	Describe("static IPs", func() {
		Test(Environment{
			Name:        "proxy-static-ip",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "proxy-static-ip-certs",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("7 added/0 skipped/0 errors"),
			},
		})
		Test(Environment{
			Name:        "broker-static-ip",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
		})
		Test(Environment{
			Name:        "static-ip-invalid",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("single IPv4"),
				GenesisCheck:      ContainSubstring("single IPv4"),
				GenesisManifest:   ContainSubstring("single IPv4"),
			},
		})
		Test(Environment{
			Name:        "proxy-static-ip-list",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("IPv4"),
				GenesisCheck:      ContainSubstring("IPv4"),
				GenesisManifest:   ContainSubstring("IPv4"),
			},
		})
		Test(Environment{
			Name:        "proxy-static-ip-octet",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("IPv4"),
				GenesisCheck:      ContainSubstring("IPv4"),
				GenesisManifest:   ContainSubstring("IPv4"),
			},
		})
		Test(Environment{
			Name:        "broker-static-ip-invalid",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("IPv4"),
				GenesisCheck:      ContainSubstring("IPv4"),
				GenesisManifest:   ContainSubstring("IPv4"),
			},
		})
		Test(Environment{
			Name:        "external-rmq-lb-proxy-static-ip",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("has nothing to apply to"),
				GenesisCheck:      ContainSubstring("has nothing to apply to"),
				GenesisManifest:   ContainSubstring("has nothing to apply to"),
			},
		})
		Test(Environment{
			Name:        "static-ip-conflict",
			CloudConfig: "aws-dotted-network",
			CPI:         "aws",
			Exodus:      "cf",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("different"),
				GenesisCheck:      ContainSubstring("different"),
				GenesisManifest:   ContainSubstring("different"),
			},
		})
	})
})
