# RENETA - Recurrent Neural Network Training Accelerator with Temporal Sparsity
This repo mainly contains:
- Source codes (SystemVerilog) for RENETA, the Delta RNN training accelerator
- Training codes (Python) for the Delta RNN training algorithm, published at NeurIPS Workshop MLNCP 2023 and AAAI 2024

# Project Structure
```
.
└── HDL                     # HDL codes for RENETA accelerator
    ├── dtv1.sv                 # Top module, DTV1 is the internal code of RENETA
    ├── dtv1_bram_sdp.sv        # Simple Dual-Port (1R1W) BRAM
    ├── dtv1_bram_sp.sv         # Single Port BRAM
    ├── dtv1_ccm.sv             # CCM (Compute Core Module)
    ├── dtv1_dmx.sv             # IPM - Data Channel Multiplexer
    ├── dtv1_drg.sv             # IPM - DRAM Request Generator
    ├── dtv1_fifo.sv            # General parameterized FIFO
    ├── dtv1_macc_fp.sv         # PE array (Floating-Point)
    ├── dtv1_macc_fxp.sv        # PE array (Fixed-Point)
    ├── dtv1_tb.sv              # Testbench for simulation
    ├── dtv1_pkg.sv             # Package for common data types
    ├── dtv1_smem_fifo.sv       # SMEM - FIFO
    ├── dtv1_smem.sv            # SMEM (Shared Memory)
    ├── dtv1_spm.sv             # Sparse Data Descriptor Memory
    ├── dtv1_srg0.sv            # IPM - SMEM Request Generator CH0
    └── dtv1_srg.sv             # IPM - SMEM Request Generator CH1-2
└── DeltaRNN_IL             # Pytorch codes for training experiments, based on this repo https://github.com/gaochangw/DeltaRNN
    ├── project.py             # A class defining all major training functions and stores hyperparameters
    └── main.py                # Main
```

# Reference
If you find this repository helpful, please cite our work.
- [AAAI 2024] Exploiting Symmetric Temporally Sparse BPTT for Efficient RNN Training
```
@inproceedings{
Chen2024AAAI,
title={Exploiting Symmetric Temporally Sparse {BPTT} for Efficient {RNN} Training},
author={Xi Chen and Chang Gao and Zuowen Wang and Longbiao Cheng and Sheng Zhou and Shih-Chii Liu and Tobi Delbruck},
booktitle={The 38th Annual AAAI Conference on Artificial Intelligence},
year={2024},
}
```
- [NeurIPS Workshop MLNCP 2023] Exploiting Symmetric Temporally Sparse BPTT for Efficient RNN Training
```
@inproceedings{
Chen2023MLNCP,
title={Exploiting Symmetric Temporally Sparse {BPTT} for Efficient {RNN} Training},
author={Xi Chen and Chang Gao and Zuowen Wang and Longbiao Cheng and Sheng Zhou and Shih-Chii Liu and Tobi Delbruck},
booktitle={Machine Learning with New Compute Paradigms},
year={2023},
url={https://openreview.net/forum?id=2zXPCHKt6C}
}
```