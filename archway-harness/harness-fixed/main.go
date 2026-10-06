// archway-harness-fixed: same contract-execution harness, but linked against the
// PATCHED engine (wasmvm v3.0.8 / Wasmer 7.4.2). Run identical contracts/inputs
// through both binaries and diff results for differential testing.
package main

import (
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sort"
	"time"

	wasmvm "github.com/CosmWasm/wasmvm/v3"
	"github.com/CosmWasm/wasmvm/v3/types"
)

var defaultCapabilities = []string{"iterator", "staking", "stargate", "cosmwasm_1_1", "cosmwasm_1_2", "cosmwasm_1_3", "cosmwasm_1_4", "cosmwasm_2_0", "cosmwasm_2_1", "cosmwasm_2_2"}

// ---------------- mock KVStore ----------------

type memStore struct{ m map[string][]byte }

func newMemStore() *memStore { return &memStore{m: make(map[string][]byte)} }

func (s *memStore) Get(k []byte) []byte {
	if v, ok := s.m[string(k)]; ok {
		return v
	}
	return nil
}
func (s *memStore) Set(k, v []byte) { s.m[string(k)] = append([]byte(nil), v...) }
func (s *memStore) Delete(k []byte) { delete(s.m, string(k)) }
func (s *memStore) Iterator(start, end []byte) types.Iterator {
	return newIter(s, start, end, false)
}
func (s *memStore) ReverseIterator(start, end []byte) types.Iterator {
	return newIter(s, start, end, true)
}

type iter struct {
	keys       [][]byte
	vals       [][]byte
	i          int
	start, end []byte
}

func newIter(s *memStore, start, end []byte, reverse bool) *iter {
	all := make([]string, 0, len(s.m))
	for k := range s.m {
		if start != nil && k < string(start) {
			continue
		}
		if end != nil && k >= string(end) {
			continue
		}
		all = append(all, k)
	}
	sort.Strings(all)
	if reverse {
		for i, j := 0, len(all)-1; i < j; i, j = i+1, j-1 {
			all[i], all[j] = all[j], all[i]
		}
	}
	it := &iter{start: start, end: end}
	for _, k := range all {
		it.keys = append(it.keys, []byte(k))
		it.vals = append(it.vals, s.m[k])
	}
	return it
}

func (it *iter) Domain() ([]byte, []byte) { return it.start, it.end }
func (it *iter) Valid() bool              { return it.i >= 0 && it.i < len(it.keys) }
func (it *iter) Next()                    { it.i++ }
func (it *iter) Key() []byte              { return it.keys[it.i] }
func (it *iter) Value() []byte            { return it.vals[it.i] }
func (it *iter) Error() error             { return nil }
func (it *iter) Close() error             { return nil }

// ---------------- mocks ----------------

type mockGasMeter struct{ consumed uint64 }

func (g *mockGasMeter) GasConsumed() types.Gas { return g.consumed }

type mockQuerier struct{ gas uint64 }

func (q *mockQuerier) Query(req types.QueryRequest, gasLimit uint64) ([]byte, error) {
	return nil, fmt.Errorf("queries disabled in harness")
}
func (q *mockQuerier) GasConsumed() uint64 { return q.gas }

// nestedQuerier routes Smart queries to a second contract (nested wasmvm execution).
type nestedQuerier struct {
	vm        *wasmvm.VM
	checksum  wasmvm.Checksum
	env       types.Env
	store     types.KVStore
	goapi     types.GoAPI
	gasLimit  uint64
	deserCost types.UFraction
	calls     int
}

func (q *nestedQuerier) Query(req types.QueryRequest, gasLimit uint64) ([]byte, error) {
	if req.Wasm == nil || req.Wasm.Smart == nil {
		return nil, fmt.Errorf("nestedQuerier: only smart queries are supported")
	}
	q.calls++
	res, _, err := q.vm.Query(q.checksum, q.env, req.Wasm.Smart.Msg, q.store, q.goapi, q, &mockGasMeter{}, q.gasLimit, q.deserCost)
	if err != nil {
		return nil, err
	}
	if res == nil {
		return nil, fmt.Errorf("nil query result")
	}
	if res.Err != "" {
		return nil, fmt.Errorf("%s", res.Err)
	}
	return res.Ok, nil
}
func (q *nestedQuerier) GasConsumed() uint64 { return 0 }

func humanAddress(canonical []byte) (string, uint64, error) {
	return hex.EncodeToString(canonical), 10, nil
}
func canonicalAddress(human string) ([]byte, uint64, error) {
	b, err := hex.DecodeString(human)
	return b, 10, err
}
func validateAddress(human string) (uint64, error) { return 10, nil }

// ---------------- main ----------------

type stepResult struct {
	Gas      uint64          `json:"gas"`
	Error    string          `json:"error,omitempty"`
	Response json.RawMessage `json:"response,omitempty"`
}

type report struct {
	Wasm         string       `json:"wasm"`
	Checksum     string       `json:"checksum"`
	Capabilities string       `json:"capabilities"`
	MemoryLimit  uint         `json:"memory_limit_mb"`
	Instantiate  stepResult   `json:"instantiate"`
	Executes     []stepResult `json:"executes"`
	TotalGas     uint64       `json:"total_gas"`
}

func main() {
	wasmFile := flag.String("wasm", "", "path to contract .wasm (required)")
	initMsg := flag.String("init", "{}", "instantiate msg JSON")
	execMsg := flag.String("exec", "{}", "execute msg JSON")
	gas := flag.Uint64("gas", 500_000_000_000, "gas limit per call (wasmvm gas units)")
	repeat := flag.Int("repeat", 1, "number of execute calls")
	memoryLimit := flag.Uint("memory-mb", 32, "memory limit (MiB)")
	printDebug := flag.Bool("print-debug", false, "print VM debug output")
	outFile := flag.String("out", "", "write JSON report to this file")
	triggerFile := flag.String("trigger", "", "drift trigger .wasm (enables nested holder/trigger mode)")
	benignFile := flag.String("benign", "", "benign trigger .wasm for nested warm-ups")
	warmups := flag.Int("warmups", 0, "nested warm-up executions to grow the coroutine stack pool")
	flag.Parse()

	if *wasmFile == "" {
		fmt.Fprintln(os.Stderr, "usage: harness-fixed -wasm contract.wasm [-init json] [-exec json] [-repeat N] [-gas N]")
		os.Exit(2)
	}
	code, err := os.ReadFile(*wasmFile)
	if err != nil {
		fmt.Fprintln(os.Stderr, "read wasm:", err)
		os.Exit(2)
	}

	dataDir, err := os.MkdirTemp("", "wasmvm-harness-fixed-")
	if err != nil {
		fmt.Fprintln(os.Stderr, "tmpdir:", err)
		os.Exit(2)
	}
	defer os.RemoveAll(dataDir)

	vm, err := wasmvm.NewVM(dataDir, defaultCapabilities, uint32(*memoryLimit), *printDebug, 0)
	if err != nil {
		fmt.Fprintln(os.Stderr, "NewVM:", err)
		os.Exit(2)
	}
	defer vm.Cleanup()

	checksum, _, err := vm.StoreCode(code, *gas)
	if err != nil {
		fmt.Fprintln(os.Stderr, "StoreCode:", err)
		os.Exit(2)
	}

	// nested mode: store the drift trigger + the benign warm-up trigger
	var triggerChecksum, benignChecksum wasmvm.Checksum
	if *triggerFile != "" {
		tcode, err := os.ReadFile(*triggerFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, "read trigger:", err)
			os.Exit(2)
		}
		triggerChecksum, _, err = vm.StoreCode(tcode, *gas)
		if err != nil {
			fmt.Fprintln(os.Stderr, "StoreCode trigger:", err)
			os.Exit(2)
		}
	}
	if *benignFile != "" {
		bcode, err := os.ReadFile(*benignFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, "read benign:", err)
			os.Exit(2)
		}
		benignChecksum, _, err = vm.StoreCode(bcode, *gas)
		if err != nil {
			fmt.Fprintln(os.Stderr, "StoreCode benign:", err)
			os.Exit(2)
		}
	}

	store := newMemStore()
	env := types.Env{
		Block: types.BlockInfo{
			Height:  17645027,
			Time:    types.Uint64(time.Now().UnixNano()),
			ChainID: "archway-1",
		},
		Transaction: &types.TransactionInfo{Index: 0},
		Contract:    types.ContractInfo{Address: "archway1harnesscontract0000000000000000000000000"},
	}
	info := types.MessageInfo{
		Sender: "archway1harnesssender00000000000000000000000000",
		Funds:  types.Array[types.Coin]{},
	}
	goapi := types.GoAPI{
		HumanizeAddress:     humanAddress,
		CanonicalizeAddress: canonicalAddress,
		ValidateAddress:     validateAddress,
	}
	var querier types.Querier = &mockQuerier{}
	deserCost := types.UFraction{Numerator: 1, Denominator: 1}

	rep := report{
		Wasm:         *wasmFile,
		Checksum:     hex.EncodeToString(checksum),
		Capabilities: fmt.Sprint(defaultCapabilities),
		MemoryLimit:  *memoryLimit,
	}

	res, g, err := vm.Instantiate(checksum, env, info, []byte(*initMsg), store, goapi, querier, &mockGasMeter{}, *gas, deserCost)
	rep.Instantiate = stepResult{Gas: g}
	if err != nil {
		rep.Instantiate.Error = err.Error()
	} else if res != nil {
		if res.Err != "" {
			rep.Instantiate.Error = res.Err
		} else if res.Ok != nil {
			b, _ := json.Marshal(res.Ok)
			rep.Instantiate.Response = b
		}
	}
	rep.TotalGas += g
	if err != nil || rep.Instantiate.Error != "" {
		writeReport(rep, *outFile)
		fmt.Fprintln(os.Stderr, "instantiate error:", rep.Instantiate.Error)
		os.Exit(1)
	}

	// nested mode: instantiate the triggers, warm up the stack pool, then attack
	if *triggerFile != "" {
		if _, _, err := vm.Instantiate(triggerChecksum, env, info, []byte("{}"), store, goapi, &mockQuerier{}, &mockGasMeter{}, *gas, deserCost); err != nil {
			fmt.Fprintln(os.Stderr, "instantiate trigger:", err)
			os.Exit(2)
		}
		nq := &nestedQuerier{vm: vm, checksum: triggerChecksum, env: env, store: store, goapi: goapi, gasLimit: *gas, deserCost: deserCost}
		if *benignFile != "" && *warmups > 0 {
			if _, _, err := vm.Instantiate(benignChecksum, env, info, []byte("{}"), store, goapi, &mockQuerier{}, &mockGasMeter{}, *gas, deserCost); err != nil {
				fmt.Fprintln(os.Stderr, "instantiate benign:", err)
				os.Exit(2)
			}
			nq.checksum = benignChecksum
			for i := 0; i < *warmups; i++ {
				_, _, werr := vm.Execute(checksum, env, info, []byte(*execMsg), store, goapi, nq, &mockGasMeter{}, *gas, deserCost)
				fmt.Fprintf(os.Stderr, "warmup %d err=%v nested_calls=%d\n", i, werr, nq.calls)
			}
		}
		nq.checksum = triggerChecksum
		querier = nq
		fmt.Fprintf(os.Stderr, "nested mode armed: trigger=%v warmups=%d\n", triggerChecksum, *warmups)
	}

	for i := 0; i < *repeat; i++ {
		res, g, err := vm.Execute(checksum, env, info, []byte(*execMsg), store, goapi, querier, &mockGasMeter{}, *gas, deserCost)
		sr := stepResult{Gas: g}
		if err != nil {
			sr.Error = err.Error()
		} else if res != nil {
			if res.Err != "" {
				sr.Error = res.Err
			} else if res.Ok != nil {
				b, _ := json.Marshal(res.Ok)
				sr.Response = b
			}
		}
		rep.Executes = append(rep.Executes, sr)
		rep.TotalGas += g
		if err != nil || sr.Error != "" {
			writeReport(rep, *outFile)
			fmt.Fprintln(os.Stderr, "execute error:", sr.Error)
			os.Exit(1)
		}
	}

	writeReport(rep, *outFile)
	fmt.Printf("OK checksum=%s instantiate_gas=%d exec_gas=%d total_gas=%d\n",
		rep.Checksum, rep.Instantiate.Gas, rep.Executes[0].Gas, rep.TotalGas)
}

func writeReport(r report, out string) {
	b, _ := json.MarshalIndent(r, "", "  ")
	if out != "" {
		_ = os.WriteFile(out, b, 0o644)
	}
	fmt.Println(string(b))
}
