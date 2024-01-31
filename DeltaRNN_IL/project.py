__author__ = "Chang Gao"
__copyright__ = "Copyright @ Chang Gao"
__credits__ = ["Chang Gao"]
__license__ = "Private"
__version__ = "0.0.1"
__maintainer__ = "Chang Gao"
__email__ = "gaochangw@outlook.com"
__status__ = "Prototype"

import importlib
import json
import os
import time
import typing
import argparse
import random as rnd
import numpy as np
import torch
import torch.nn as nn
from torch import optim
from torch.nn import CTCLoss
from tqdm import tqdm
from utils import pandaslogger, util
from thop import profile
import copy


class Project:
    def __init__(self):
        self.testfile = None
        # self.devfile = None
        self.trainfile = None
        self.dataloader = None
        self.config = None
        self.hparams = None
        self.args = None
        self.num_cpu_threads = os.cpu_count()  # Hardware Info
        self.load_arguments()  # Load Arguments
        self.load_modules()  # Load Modules of a specific dataset
        self.load_config()  # Load Configurations
        self.update_args()  # Update arguments according to the current step
        self.exemplar_sets = {}
        self.exemplar_sets_means = None
        self.q = None

        # Define abbreviations of hparams
        self.args_to_abb = {
            'seed': 'S',
            'input_size': 'I',
            'rnn_size': 'H',
            'rnn_type': 'T',
            'rnn_layers': 'L',
            'num_classes': 'C',
            'ctxt_size': 'CT',
            'pred_size': 'PD',
            'qa': 'QA',
            'aqi': 'AQI',
            'aqf': 'AQF',
            'qw': 'QW',
            'wqi': 'WQI',
            'wqf': 'WQF',
        }
        self.abb_to_args = dict((v, k) for k, v in self.args_to_abb.items())
        self.experiment_key = None

        # Manage Steps
        self.list_steps = ['prepare', 'feature', 'pretrain', 'retrain']
        self.additem('step_idx', self.list_steps.index(self.step))

    def additem(self, key, value):
        setattr(self, key, value)
        setattr(self.args, key, value)
        self.hparams[key] = value

    def load_config(self):
        config_path = os.path.join('./config', self.dataset, self.cfg_feat + '.json')
        with open(config_path) as config_file:
            self.config = json.load(config_file)
        for k, v in self.config.items():
            setattr(self, k, v)
            self.hparams[k] = v

    def step_in(self):
        if self.run_through:
            self.additem('step_idx', self.step_idx + 1)
            self.additem('step', self.list_steps[self.step_idx])

    def gen_experiment_key(self, **kwargs) -> str:
        from operator import itemgetter

        # Add extra arguments if needed
        args_to_abb = {**self.args_to_abb, **kwargs}

        # Model ID
        list_args = list(args_to_abb.keys())
        list_abbs = list(itemgetter(*list_args)(args_to_abb))
        list_vals = list(itemgetter(*list_args)(self.hparams))
        list_vals_str = list(map(str, list_vals))
        experiment_key = list_abbs + list_vals_str
        experiment_key[::2] = list_abbs
        experiment_key[1::2] = list_vals_str
        experiment_key = '_'.join(experiment_key)
        self.experiment_key = experiment_key
        return experiment_key

    def decode_exp_id(self, exp_id: str):
        args = exp_id.split('_')
        vals = args[1::2]
        args = args[0::2]
        args = [self.abb_to_args[x] for x in args]
        dict_arg = dict(zip(args, vals))
        return dict_arg

    def reproducible(self, level='soft'):
        rnd.seed(self.seed)
        np.random.seed(self.seed)
        torch.manual_seed(self.seed)
        torch.cuda.manual_seed_all(self.seed)
        if level == 'soft':
            torch.use_deterministic_algorithms(mode=False)
        else:  # level == 'hard'
            torch.use_deterministic_algorithms(mode=True)
        torch.cuda.empty_cache()
        print("::: Are Deterministic Algorithms Enabled: ", torch.are_deterministic_algorithms_enabled())
        print("--------------------------------------------------------------------")

    def load_modules(self):
        # Load Modules
        print("### Loading modules for dataset: ", self.dataset)
        try:
            self.data_prep = importlib.import_module('modules.' + self.dataset + '.data_prep')
        except:
            raise RuntimeError('Please select a supported dataset.')
        try:
            self.dataloader = importlib.import_module('modules.' + self.dataset + '.dataloader')
        except:
            raise RuntimeError('Please select a supported dataset.')
        try:
            self.log = importlib.import_module('modules.' + self.dataset + '.log')
        except:
            raise RuntimeError('Please select a supported dataset.')
        try:
            self.train_func = importlib.import_module('modules.' + self.dataset + '.train_func')
        except:
            raise RuntimeError('Please select a supported dataset.')
        try:
            self.metric = importlib.import_module('modules.' + self.dataset + '.metric')
        except:
            raise RuntimeError('Please select a supported dataset.')
        try:
            self.net_pretrain = importlib.import_module('networks.models.' + self.model_pretrain)
        except:
            raise RuntimeError(f"Cannot import pretrain module \'networks.models.{self.model_pretrain}\'!")
        if self.step == 'retrain':
            try:
                self.net_retrain = importlib.import_module('networks.models.' + self.model_retrain)
            except:
                raise RuntimeError(f"Cannot import retrain module \'networks.models.{self.model_retrain}\'!")

    def load_arguments(self):
        parser = argparse.ArgumentParser(description='Train a GRU network.')
        # Basic Setup
        args_basic = parser.add_argument_group("Basic Setup")
        args_basic.add_argument('--project_name', default='AMPRO', help='Useful for loggers like Comet')
        args_basic.add_argument('--data_dir', default='/DATA', help='Useful for loggers like Comet')
        args_basic.add_argument('--dataset', default='gscdv2', help='Useful for loggers like Comet')
        args_basic.add_argument('--cfg_feat', default='feat_fft', help='Useful for loggers like Comet')
        # args_basic.add_argument('--path_net_pretrain', default=None, help='Useful for loggers like Comet')
        args_basic.add_argument('--trainfile', default=None, help='Training set feature path')
        # args_basic.add_argument('--devfile', default=None, help='Development set feature path')
        args_basic.add_argument('--testfile', default=None, help='Test set feature path')
        args_basic.add_argument('--step', default='pretrain', help='A specific step to run.')
        args_basic.add_argument('--run_through', default=0, type=int, help='If true, run all following steps.')
        args_basic.add_argument('--eval_val', default=1, type=int, help='Whether eval val set during training')
        args_basic.add_argument('--score_val', default=1, type=int, help='Whether score val set during training')
        args_basic.add_argument('--eval_test', default=1, type=int, help='Whether eval test set during training')
        args_basic.add_argument('--score_test', default=1, type=int, help='Whether score test set during training')
        args_basic.add_argument('--debug', default=0, type=int, help='Log intermediate results for hardware debugging')
        args_basic.add_argument('--model_path', default='',
                                help='Model path to load. If empty, the experiment key will be used.')
        args_basic.add_argument('--use_cuda', default=1, type=int, help='Use GPU')
        args_basic.add_argument('--gpu_device', default=0, type=int, help='Select GPU')
        args_basic.add_argument('--write_log', default=1, type=int, help='Write log to a csv file')
        args_basic.add_argument('--save_best_model', default=1, type=int, help='Save the best model during training')
        args_basic.add_argument('--save_every_epoch', default=0, type=int, help='Save model for every epoch.')
        args_basic.add_argument('--custom_string', default='', help='Custom string added to log/save filename')
        args_basic.add_argument('--pretrain_file', default='', help='Custom pretrain model filename')
        # Dataset Processing/Feature Extraction
        args_feat = parser.add_argument_group("Dataset Processing/Feature Extraction")
        args_feat.add_argument('--augment_noise', default=0, type=int, help='Augment data with various SNRs')
        args_feat.add_argument('--target_snr', default=5, type=int, help='Signal-to-Noise ratio for test')
        args_feat.add_argument('--zero_padding', default='head',
                               help='Method of padding zeros to samples in a batch')
        args_feat.add_argument('--qf', default=0, type=int, help='Quantize features')
        args_feat.add_argument('--logf', default=None, help='Apply a log function on the feature; log - '
                                                            'floating-point log function; 2 - Look-Up '
                                                            'Table-based log function')
        # Training Hyperparameters
        args_hparam_t = parser.add_argument_group("Training Hyperparameters")
        args_hparam_t.add_argument('--seed', default=0, type=int, help='Random seed.')
        args_hparam_t.add_argument('--epochs_pretrain', default=50, type=int, help='Number of epochs to train for.')
        args_hparam_t.add_argument('--epochs_retrain', default=50, type=int, help='Number of epochs to train for.')
        args_hparam_t.add_argument('--batch_size', default=64, type=int, help='Batch size.')
        args_hparam_t.add_argument('--batch_size_eval', default=256, type=int,
                                   help='Batch size for test. Use larger values for faster test.')
        args_hparam_t.add_argument('--opt', default='ADAMW', help='Which optimizer to use (ADAM or SGD)')
        args_hparam_t.add_argument('--lr_schedule', default=1, type=int, help='Whether enable learning rate scheduling')
        args_hparam_t.add_argument('--lr', default=1e-3, type=float, help='Learning rate')  # 5e-4
        args_hparam_t.add_argument('--lr_end', default=3e-4, type=float, help='Learning rate')
        args_hparam_t.add_argument('--decay_factor', default=0.8, type=float, help='Learning rate')
        args_hparam_t.add_argument('--patience', default=4, type=float, help='Learning rate')
        args_hparam_t.add_argument('--beta', default=0, type=float,
                                   help='Weighting factor for sparsity cost added to loss function for training')
        args_hparam_t.add_argument('--loss', default='crossentropy', help='Loss function.')
        args_hparam_t.add_argument('--weight_decay', default=0.01, type=float, help='Weight decay')
        args_hparam_t.add_argument('--grad_clip_val', default=200, type=float, help='Gradient clipping')
        args_hparam_t.add_argument('--ctxt_size', default=100, type=int,
                                   help='The number of timesteps for RNN to look at')
        args_hparam_t.add_argument('--pred_size', default=1, type=int,
                                   help='The number of timesteps to predict in the future')
        # RNN Model Hyperparameters
        args_hparam_rnn = parser.add_argument_group("Model Hyperparameters")
        args_hparam_rnn.add_argument('--model_pretrain', default='cla-rnn', help='Network model for pretrain')
        args_hparam_rnn.add_argument('--model_retrain', default='cla-deltarnn', help='Network model for retrain')
        args_hparam_rnn.add_argument('--rnn_type', default='GRU', help='RNN layer type')
        args_hparam_rnn.add_argument('--rnn_layers', default=1, type=int, help='Number of RNN nnlayers')
        args_hparam_rnn.add_argument('--rnn_size', default=64, type=int,
                                   help='RNN Hidden layer size (must be a multiple of num_pe, see modules/edgedrnn.py)')
        args_hparam_rnn.add_argument('--rnn_dropout', default=0, type=float, help='RNN Hidden layer size')
        args_hparam_rnn.add_argument('--fc_extra_size', default=0, type=float, help='RNN Hidden layer size')
        args_hparam_rnn.add_argument('--fc_dropout', default=0, type=float, help='RNN Hidden layer size')
        args_hparam_rnn.add_argument('--use_hardsigmoid', default=0, type=int, help='Use hardsigmoid')
        args_hparam_rnn.add_argument('--use_hardtanh', default=0, type=int, help='Use hardtanh')
        # Quantization
        args_hparam_q = parser.add_argument_group("Quantization Hyperparameters")
        args_hparam_q.add_argument('--qa', default=0, type=int, help='Quantize the activations')
        args_hparam_q.add_argument('--qw', default=0, type=int, help='Quantize the weights')
        args_hparam_q.add_argument('--qc', default=0, type=int, help='Quantize the classification layer (CL)')
        args_hparam_q.add_argument('--qcw', default=0, type=int, help='Quantize the classification layer (CL) weights')
        args_hparam_q.add_argument('--aqi', default=3, type=int,
                                   help='Number of integer bits before decimal point for activation')
        args_hparam_q.add_argument('--aqf', default=5, type=int,
                                   help='Number of integer bits after decimal point for activation')
        args_hparam_q.add_argument('--wqi', default=1, type=int,
                                   help='Number of integer bits before decimal point for weight')
        args_hparam_q.add_argument('--wqf', default=7, type=int,
                                   help='Number of integer bits after decimal point for weight')
        args_hparam_q.add_argument('--bw_acc', default=32, type=int,
                                   help='Bit width of the MAC accumulator')
        args_hparam_q.add_argument('--nqi', default=2, type=int,
                                   help='Number of integer bits before decimal point for AF')
        args_hparam_q.add_argument('--nqf', default=6, type=int,
                                   help='Number of integer bits after decimal point for AF')
        args_hparam_q.add_argument('--cqi', default=3, type=int,
                                   help='Number of integer bits before decimal point for CL')
        args_hparam_q.add_argument('--cqf', default=5, type=int,
                                   help='Number of integer bits after decimal point for CL')
        args_hparam_q.add_argument('--cwqi', default=1, type=int,
                                   help='Number of integer bits before decimal point for CL')
        args_hparam_q.add_argument('--cwqf', default=7, type=int,
                                   help='Number of integer bits after decimal point for CL')
        # Delta Networks
        args_hparam_d = parser.add_argument_group("Delta Network Hyperparameters")
        args_hparam_d.add_argument('--thx', default=0, type=float, help='Delta threshold for inputs')
        args_hparam_d.add_argument('--thh', default=0, type=float, help='Delta threshold for hidden states')
        # Scoring Settings
        args_score = parser.add_argument_group("Scoring Hyperparameters")
        args_score.add_argument('--smooth', default=1, type=int, help='Whether smooth the posterior over time')
        args_score.add_argument('--smooth_window_size', default=60, type=int, help='Posterior smooth window size')
        args_score.add_argument('--confidence_window_size', default=80, type=int,
                                help='Confidence score window size')
        args_score.add_argument('--fire_threshold', default=0, type=float,
                                help='Threshold for train (1) firing a decision')
        # Get EdgeDRNN-Specific Arguments
        args_edgedrnn = parser.add_argument_group("EdgeDRNN Arguments")
        args_edgedrnn.add_argument('--stim_head', default=1000, type=int, help='Starting index of the HDL test stimuli')
        args_edgedrnn.add_argument('--stim_len', default=1000, type=int, help='#Timesteps of the HDL test stimuli')
        # CBTD
        args_cbtd = parser.add_argument_group("Column-Balanced Targeted Dropout Arguments")
        args_cbtd.add_argument('--cbtd', default=0, type=int,
                               help='Whether use Column-Balanced Weight Dropout')
        args_cbtd.add_argument('--gamma_rnn', default=0.7, type=float, help='Target sparsity of cbtd')
        args_cbtd.add_argument('--gamma_fc', default=0.75, type=float, help='Target sparsity of cbtd')
        args_cbtd.add_argument('--alpha_anneal_epoch', default=0, type=int, help='Target sparsity of cbtd')
        # Get Spartus-Specific Arguments
        args_spartus = parser.add_argument_group("Spartus Arguments")
        args_spartus.add_argument('--num_array', default=1, type=int, help='Number of MAC Arrays')
        args_spartus.add_argument('--num_array_pe', default=16, type=int, help='Number of PEs per MAC Array')
        args_spartus.add_argument('--num_array_pe_ext', default=8, type=int,
                                  help='Number of PEs per MAC Array for export')
        args_spartus.add_argument('--act_latency', default=8, type=int,
                                  help='Pipeline latency for calculating activations')
        args_spartus.add_argument('--act_interval', default=4, type=int,
                                  help='Pipeline latency for calculating activations')
        args_spartus.add_argument('--op_freq', default=2e8, type=int, help='Operation frequency of DeltaLSTM')
        args_spartus.add_argument('--w_sp_ext', default=0.9375, type=float, help='Weight sparsity for export')
        # Incremental Learning Arguments
        args_basic.add_argument('--il_mode', default=0, type=int, help='Incremental learning mode')
        args_basic.add_argument('--num_learned_classes', default=0, type=int, help='Number of learned classes')
        args_basic.add_argument('--num_new_classes', default=35, type=int, help='Number of new classes to learn')
        args_basic.add_argument('--num_exemplars', default=2000, type=int, help='Number of exemplars for iCaRL exemplar sets')
        args_basic.add_argument('--il_load_pretrain', default=0, type=int, help='Load from pretrain folder')
        args_basic.add_argument('--il_save_model', default=1, type=int, help='Save model and exemplar sets after training')
        args_basic.add_argument('--feat_folder', default='', help='Feature input folder')

        self.args = parser.parse_args()

        # Get Hyperparameter Dictionary
        self.hparams = vars(self.args)
        for k, v in self.hparams.items():
            setattr(self, k, v)

    def update_args(self):
        # Determine Arguments According to Steps
        if self.step == 'pretrain':
            self.additem('n_epochs', self.epochs_pretrain)
            self.additem('model_name', self.model_pretrain)
            self.additem('retrain', 0)
        elif self.step == 'retrain':
            self.additem('n_epochs', self.epochs_retrain)
            self.additem('model_name', self.model_retrain)
            self.additem('retrain', 1)
        elif self.step == 'test':
            self.additem('batch_size', self.batch_size_eval)

    def select_device(self):
        # Find Available GPUs
        if torch.cuda.is_available():
            torch.cuda.set_device(self.gpu_device)
            idx_gpu = torch.cuda.current_device()
            name_gpu = torch.cuda.get_device_name(idx_gpu)
            device = "cuda:" + str(idx_gpu)
            print("::: Available GPUs: %s" % (torch.cuda.device_count()))
            print("::: Using GPU %s:   %s" % (idx_gpu, name_gpu))
            print("--------------------------------------------------------------------")
        else:
            device = "cpu"
            print("::: Available GPUs: None")
            print("--------------------------------------------------------------------")
        self.additem("device", device)
        return device

    def build_model(self):
        from utils.util import count_net_params
        import pickle
        # Load Pretrained Model if Running Retrain
        if self.step == 'retrain':
            net = self.net_retrain.Model(self)  # Instantiate Retrain Model
            # if self.path_net_pretrain is None:
            #     print('::: Loading pretrained model: ', self.default_path_net_pretrain)
            #     # net = util.load_model(self, net, self.default_path_net_pretrain)
            #     net.load_pretrain_model(self.default_path_net_pretrain)
            # else:
            #     print('::: Loading pretrained model: ', self.path_net_pretrain)
            #     net = util.load_model(self, net, self.path_net_pretrain)
            
            print(f"::: Loading pretrained model from \"{self.default_path_net_pretrain}\"")
            # net = util.load_model(self, net, self.default_path_net_pretrain)
            net.load_pretrain_model(self.default_path_net_pretrain, self.il_mode)
            if self.il_mode and self.num_learned_classes > 0:
                pkl_name = self.default_path_net_pretrain.replace('.pt', '.pkl')
                print(f"::: Loading exemplar sets from \"{pkl_name}\"")
                with open(pkl_name, 'rb') as fp:
                    self.exemplar_sets = pickle.load(fp)
                print(f"Exemplar sets size = {len(self.exemplar_sets)}")
        else:
            net = self.net_pretrain.Model(self)  # Instantiate Pretrain Model

        # Get parameter count
        # n_param = count_net_params(net)
        # self.additem("n_param", n_param)
        # num_macs, num_params = net.get_model_size()
        num_params = net.get_model_size()
        print("::: Number of Parameters: ", num_params)
        # print("::: Number of MACs: ", num_macs)
        # self.additem("num_macs", num_macs)
        self.additem("num_params", num_params)

        # Cast net to the target device
        net.to(self.device)
        self.additem("net", net)

        return net

    def build_criterion(self):
        # cls_weight = None
        # XXX nn.CrossEntropyLoss(weight=cls_weight, reduction='mean')
        # if self.il_mode:
        #     if self.num_learned_classes == 0:
        #         cls_old = 0
        #     else:
        #         cls_old = self.num_learned_classes + 1
        #     cls_weight = torch.ones(size=(self.num_classes,))
        #     # cls_weight[:cls_old] = 0
        #     if self.use_cuda:
        #         cls_weight = cls_weight.cuda()
        dict_loss = {'crossentropy': nn.CrossEntropyLoss(reduction='mean'),
                     'ctc': CTCLoss(blank=0, reduction='sum', zero_infinity=True),
                     'mse': nn.MSELoss(),
                     'l1': nn.L1Loss()
                     }
        loss_func_name = self.loss
        try:
            criterion = dict_loss[loss_func_name]
            self.additem("criterion", criterion)
            if self.il_mode:
                dist_loss = nn.BCELoss(reduction='mean')
                self.additem("dist_loss", dist_loss)
            return criterion
        except AttributeError:
            raise AttributeError('Please use a valid loss function. See modules/argument.py.')

    def build_logger(self):
        # Logger
        logger = pandaslogger.PandasLogger(self.logfile_hist)
        self.additem("logger", logger)
        return logger

    def build_dataloader(self):
        # Generate Feature Paths
        # No validation set in il_mode
        _, train_name, dev_name = self.log.gen_trainset_name(self)
        test_name = self.log.gen_testset_name(self)
        if self.feat_folder == '':
            self.trainfile = os.path.join('feat', self.dataset, train_name)
            # self.devfile = os.path.join('feat', self.dataset, dev_name)
            self.testfile = os.path.join('feat', self.dataset, test_name)
        else:
            self.trainfile = os.path.join('feat', self.dataset, self.feat_folder, train_name)
            # self.devfile = os.path.join('feat', self.dataset, self.feat_folder, dev_name)
            self.testfile = os.path.join('feat', self.dataset, self.feat_folder, test_name)
        self.dataloader = self.dataloader.DataLoader(self)
        print("::: Train File: ", self.trainfile)
        # print("::: Dev File: ", self.devfile)
        print("::: Test File: ", self.testfile)
        print("--------------------------------------------------------------------")
        return self.dataloader

    def build_structure(self):
        """
        Build project folder structure
        """
        dir_paths, file_paths, default_path_net_pretrain = self.log.gen_paths(self)
        self.additem('default_path_net_pretrain', default_path_net_pretrain)
        save_dir, log_dir_hist, log_dir_best, _ = dir_paths
        self.save_file, self.logfile_hist, self.logfile_best, _ = file_paths
        util.create_folder([save_dir, log_dir_hist, log_dir_best])
        print("::: Save Path: ", self.save_file)
        print("::: Log Path: ", self.logfile_hist)
        print("--------------------------------------------------------------------")
        self.additem('save_file', self.save_file)
        self.additem('logfile_hist', self.logfile_hist)
        self.additem('logfile_best', self.logfile_best)

    def build_optimizer(self, net=None):
        # Optimizer
        net = self.net if net is None else net
        if self.opt == 'ADAM':
            optimizer = optim.Adam(net.parameters(), lr=self.lr, amsgrad=False, weight_decay=self.weight_decay)
        elif self.opt == 'SGD':
            optimizer = optim.SGD(net.parameters(), lr=self.lr, momentum=0.9)
        elif self.opt == 'RMSPROP':
            optimizer = optim.RMSprop(net.parameters(), lr=0.0016, alpha=0.95, eps=1e-08, weight_decay=0, momentum=0,
                                      centered=False)
        elif self.opt == 'ADAMW':
            optimizer = optim.AdamW(net.parameters(), lr=self.lr, amsgrad=False, weight_decay=self.weight_decay)
        elif self.opt == 'AdaBound':
            import adabound  # Run pip install adabound (https://github.com/Luolc/AdaBound)
            optimizer = adabound.AdaBound(net.parameters(), lr=self.lr, final_lr=0.1)
        else:
            raise RuntimeError('Please use a valid optimizer.')
        self.additem("optimizer", optimizer)

        # Learning Rate Scheduler
        lr_scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer=self.optimizer,
                                                            mode='min',
                                                            factor=self.decay_factor,
                                                            patience=self.patience,
                                                            verbose=True,
                                                            threshold=1e-4,
                                                            min_lr=self.lr_end)
        self.additem("lr_scheduler", lr_scheduler)
        return optimizer, lr_scheduler

    def build_meter(self):
        meter = self.metric.Meter(self)
        self.additem("meter", meter)
        return meter

    def net_forward(self, set_name, meter):
        # Enable Debug
        try:
            self.net.set_debug(self.debug)
        except:
            pass

        # Assign methods to be used
        get_batch_data = self.train_func.get_batch_data
        calculate_loss = self.train_func.calculate_loss
        forward_propagation = self.train_func.forward_propagation

        with torch.no_grad():
            # Set Network Properties
            self.net = self.net.eval()

            # Statistics
            epoch_loss = 0.
            epoch_regularizer = 0.
            n_batches = 0

            # Dataloader
            dataloader = self.dataloader.dev_loader if set_name == 'dev' else self.dataloader.test_loader

            # Batch Iteration
            for batch_origin in tqdm(dataloader, desc=set_name):
                
                batch = copy.deepcopy(batch_origin)
                del batch_origin

                # Get Batch Data
                dict_batch_tensor = get_batch_data(self, batch)

                # Forward Propagation
                net_out, reg = forward_propagation(self.net, dict_batch_tensor)

                # Calculate Loss
                loss, loss_reg = calculate_loss(self,
                                                net_out=net_out,
                                                dict_batch=dict_batch_tensor,
                                                reg=reg)

                # Increment monitoring variables
                batch_loss = loss.item()
                epoch_loss += batch_loss  # Accumulate loss
                epoch_regularizer += loss_reg.detach().item()
                n_batches += 1  # Accumulate count so we can calculate mean later

                # Collect Meter Data
                if meter is not None:
                    # dict_batch_tensor['features'] = dict_batch_tensor['features'].transpose(0, 1)
                    # meter.add_data(**dict_batch_tensor,
                    #                outputs=net_out)
                    meter.add_data(flags=dict_batch_tensor['flags'], outputs=net_out)

                # Garbage collection to free VRAM
                del dict_batch_tensor, loss, net_out

            # Average loss and regularizer values across all batches
            epoch_loss = epoch_loss / float(n_batches)
            epoch_regularizer = epoch_regularizer / float(n_batches)

            #######################
            # Save Statistics
            #######################
            # Add basic stats
            stat = {'loss': epoch_loss, 'reg': epoch_regularizer, 'lr_criterion': epoch_loss}
            if self.net.debug:
                stat.update(self.net.statistics)
            # Get DeltaRNN Stats
            # if "Delta" in self.rnn_type and self.drnn_stats:

            # if "delta" in self.model_name:
            #     # Evaluate temporal sparsity
            #     dict_stats = net.rnn.get_temporal_sparsity()
            #     stat['sp_dx'] = dict_stats['sparsity_delta_x']
            #     stat['sp_dh'] = dict_stats['sparsity_delta_h']

            # Evaluate workload
            # dict_stats = net.rnn.get_workload()
            # print("worst_array_work: ", dict_stats['expect_worst_array_work'])
            # print("mean_array_work:  ", dict_stats['expect_mean_array_work'])
            # print("balance:          ", dict_stats['balance'])
            # print("eff_throughput:   ", dict_stats['eff_throughput'])
            # print("utilization:      ", dict_stats['utilization'])

            # net.rnn.reset_stats()
            # net.rnn.reset_debug()

            # Evaluate network output
            # if get_net_out_stat is not None:
            # stat = get_net_out_stat(self, stat, dict_meter_data)
            return meter, stat

    def net_forward_backward(self, meter):
        # Disable Debug
        try:
            self.net.set_debug(0)
        except:
            pass

        # Assign methods to be used
        get_batch_data = self.train_func.get_batch_data
        if self.il_mode == 0:
            calculate_loss = self.train_func.calculate_loss
        else:
            calculate_loss = self.train_func.calculate_loss_il
        add_meter_data = self.train_func.add_meter_data
        forward_propagation = self.train_func.forward_propagation

        # Set Network Properties
        self.net = self.net.train()

        # Stat
        epoch_loss = 0
        epoch_regularizer = 0
        n_batches = 0

        # Meter data buffer
        dict_meter_data = {}
        if self.net.debug:
            dict_meter_data.update({'net_out': [], 'net_qout': []})

        for batch_origin in tqdm(self.dataloader.train_loader, desc='Train'):
            
            batch = copy.deepcopy(batch_origin)
            del batch_origin

            # Get Batch Data
            batch = get_batch_data(self, batch)

            # Optimization
            self.optimizer.zero_grad()

            # Forward Propagation
            net_out, reg = forward_propagation(self.net, batch)

            # Calculate Loss
            loss, loss_reg = calculate_loss(self,
                                            net_out=net_out,
                                            dict_batch=batch,
                                            reg=reg)

            # Get Network Outputs Statistics
            if self.net.debug:
                if n_batches == 0:
                    net_out_min = torch.min(net_out).item()
                    net_out_max = torch.max(net_out).item()
                else:
                    min_cand = torch.min(net_out)
                    max_cand = torch.max(net_out)
                    if min_cand < net_out_min:
                        net_out_min = min_cand.item()
                    if max_cand > net_out_max:
                        net_out_max = max_cand.item()

            # Backward propagation
            loss.backward()

            # Gradient clipping
            if self.grad_clip_val != 0:
                nn.utils.clip_grad_norm_(self.net.parameters(), self.grad_clip_val)

            # Update parameters
            self.optimizer.step()

            # Increment monitoring variables
            loss.detach()
            batch_loss = loss.item()
            epoch_loss += batch_loss  # Accumulate loss
            epoch_regularizer += loss_reg.detach().item()
            n_batches += 1  # Accumulate count so we can calculate mean later

            # Collect Meter Data
            if self.net.debug:
                net_out_cpu = net_out.detach().cpu()
                net_qout_cpu = util.quantize_tensor(net_out_cpu,
                                                    self.cqi,
                                                    self.cqf,
                                                    1)
                dict_meter_data['net_out'].append(net_out_cpu)
                dict_meter_data['net_qout'].append(net_qout_cpu)
                for k, v in batch.items():
                    if k == 'features':
                        continue
                    try:
                        dict_meter_data[k].append(v.detach().cpu())
                    except:
                        dict_meter_data[k] = []

            # Garbage collection to free VRAM
            del batch, loss, reg, net_out

        # Average loss and regularizer values across batches
        epoch_loss /= n_batches
        epoch_loss = epoch_loss
        epoch_regularizer /= n_batches

        # Collect outputs and targets
        if meter is not None:
            meter = add_meter_data(meter, dict_meter_data)

        # Get network statistics
        stat = {'LOSS': epoch_loss, 'REG': epoch_regularizer}
        if self.net.debug:
            stat.update({'NET_OUT_MIN': net_out_min, 'NET_OUT_MAX': net_out_max})
            stat.update(self.net.statistics)
            stat = self.train_func.get_net_out_stat(self, stat, dict_meter_data)
        return meter, stat

    def learn(self):
        from modules.gscdv2.log import print_log, gen_log_stat, save_best_model
        ###########################################################################################################
        # Training
        ###########################################################################################################
        # Value for Saving Best Model
        best_metric = None
        # Timer
        start_time = time.time()

        # Epoch loop
        print("Starting training...")
        for epoch in range(self.n_epochs):
            # Update shuffle type
            # train_shuffle_type = 'random' if epoch > 100 else 'high_throughput'
            # Update Alpha
            alpha = 1 if self.retrain else min(epoch / (self.alpha_anneal_epoch - 1), 1.0)
            
            if self.retrain:
                # Learning rate warmup
                if epoch <= 0:
                    for param_group in self.optimizer.param_groups:
                        param_group["lr"] = self.lr * 0.1
                elif epoch == 1:
                    for param_group in self.optimizer.param_groups:
                        param_group["lr"] = self.lr

            # -----------
            # Train
            # -----------
            _, train_stat = self.net_forward_backward(meter=None)

            # Process Network after training per epoch
            self.train_func.process_network(self, stat=train_stat, alpha=alpha)

            # -----------
            # Validation
            # -----------
            dev_stat = None
            if self.eval_val:
                self.meter, dev_stat = self.net_forward(set_name='dev', meter=self.meter)
                if self.score_val:
                    dev_stat = self.meter.get_metrics(dev_stat, self)
                self.meter.clear_data()

            # -----------
            # Test
            # -----------
            test_stat = None
            if self.eval_test:
                self.meter, test_stat = self.net_forward(set_name='test', meter=self.meter)
                if self.score_test:
                    test_stat = self.meter.get_metrics(test_stat, self)
                self.meter.clear_data()
                # print("Max: %3.4f | Min: %3.4f" % (test_stat['net_out_max'], test_stat['net_out_min']))

            ###########################################################################################################
            # Logging & Saving
            ###########################################################################################################
            # Generate Log Dict
            log_stat = gen_log_stat(self, epoch, start_time, train_stat, dev_stat, test_stat)

            # Write Log
            self.logger.load_log(log_stat=log_stat)
            if self.write_log:
                self.logger.write_log(append=True)

            # Print
            if self.alpha_anneal_epoch == 0:
                print_log(self, log_stat, train_stat, dev_stat, test_stat)
            else:
                print_log(self, log_stat, train_stat, dev_stat, test_stat, alpha=alpha)

            # Save best model
            if self.save_best_model:
                best_metric = save_best_model(proj=self,
                                            best_metric=best_metric,
                                            logger=self.logger,
                                            epoch=epoch,
                                            dev_stat=dev_stat,
                                            score_val=self.score_val,
                                            test_stat=test_stat)

            ###########################################################################################################
            # Learning Rate Schedule
            ###########################################################################################################
            # Schedule at the beginning of retrain
            if self.lr_schedule:
                if self.retrain:
                    self.lr_scheduler.step(dev_stat['lr_criterion'])
                # Schedule after the alpha annealing is over
                elif self.cbtd:
                    if epoch >= self.alpha_anneal_epoch:
                        self.lr_scheduler.step(dev_stat['lr_criterion'])
                else:
                    self.lr_scheduler.step(dev_stat['lr_criterion'])
            
            ### DEBUG: Delta LSTM3_2 ###
            # for x in np.histogram(self.net.rnn.gamma_x[0].data.detach().cpu().numpy(), bins=10):
            #     print(x)
            # for x in np.histogram(self.net.rnn.gamma_h[0].data.detach().cpu().numpy(), bins=10):
            #     print(x)
            
            ### DEBUG: Delta LSTM3_3 ###
            # for x in np.histogram(self.net.rnn.th_x[0].data.detach().cpu().numpy(), bins=10):
            #     print(x)
            # for x in np.histogram(self.net.rnn.th_h[0].data.detach().cpu().numpy(), bins=10):
            #     print(x)
        
        # print(f"torch.cuda.max_memory_allocated = {torch.cuda.max_memory_allocated():,}")
        # print(f"torch.cuda.max_memory_reserved = {torch.cuda.max_memory_reserved():,}")
        print("Training Completed...                                               ")
        print(" ")
    
    ############################################################################
    # Preprocess (iCaRL)
    def preprocess_il(self):
        
        dataset = self.dataloader.train_set
        
        # Form combined training set
        print(f"trainset num_samples = {dataset.num_samples:d}")
        for y in self.exemplar_sets:
            dataset.re_add_items(self.exemplar_sets[y])
        # print(f"Added {:d} samples from previous exemplar sets to trainset")
        print(f"trainset num_samples = {dataset.num_samples:d}")
        
        # Store network outputs with pre-update parameters
        net = self.net
        
        # Disable Debug
        try:
            net.set_debug(0)
        except:
            pass
        
        # Assign methods to be used
        get_batch_data = self.train_func.get_batch_data
        forward_propagation = self.train_func.forward_propagation
        
        # Store network outputs with relative indices of dataset
        q_list = []
        
        with torch.no_grad():
            # Set Network Properties
            net = net.eval()
            
            # No shuffle
            dataloader = self.dataloader.dev_loader
            
            # Calculate outputs for input features in old exemplar sets
            for batch_origin in tqdm(dataloader, desc='Preprocessing'):

                batch = copy.deepcopy(batch_origin)
                del batch_origin

                # Get Batch Data
                dict_batch_tensor = get_batch_data(self, batch)
                # print(dict_batch_tensor['indices'])

                # Pad input sequences to max length
                seq_len, batch_size, num_features = dict_batch_tensor['features'].size()
                pad_len = dataset.max_feature_length_all - seq_len
                if pad_len > 0:
                    device = dict_batch_tensor['features'].device
                    pad_tensor = torch.zeros((pad_len, batch_size, num_features), device=device)
                    dict_batch_tensor['features'] = torch.cat((dict_batch_tensor['features'], pad_tensor), dim=0)   # (Nt, Nb, Nf)
                    pad_tensor = torch.zeros((batch_size, pad_len), device=device)
                    dict_batch_tensor['targets'] = torch.cat((dict_batch_tensor['targets'], pad_tensor), dim=1)     # (Nb, Nt)
                
                # Forward Propagation
                net_out, reg = forward_propagation(self.net, dict_batch_tensor)
                
                # (Nb, Nt, C)
                q_list.append(torch.sigmoid(net_out).detach().cpu())
                
                del net_out, reg
        
        # On GPU
        self.q = torch.cat(q_list, dim=0)
        # print(self.q.data.size())
        
        # print(torch.cuda.memory_summary())
        # print(f"torch.cuda.memory_allocated = {torch.cuda.memory_allocated():,}")
        # print(f"torch.cuda.memory_reserved = {torch.cuda.memory_reserved():,}")
        # print(f"torch.cuda.max_memory_allocated = {torch.cuda.max_memory_allocated():,}")
        # print(f"torch.cuda.max_memory_reserved = {torch.cuda.max_memory_reserved():,}")
        
        return
    
    ############################################################################
    # Reduce old exemplar sets (iCaRL)
    def reduce_exemplar_sets(self):
        for y in self.exemplar_sets.keys():
            m = int(self.num_exemplars / self.num_classes)  # Number of exemplars per class
            self.exemplar_sets[y] = self.exemplar_sets[y][:m]

    ############################################################################
    # Construct new exemplar sets (iCaRL)
    # Reference: https://github.com/donlee90/icarl
    def construct_exemplar_sets(self):
        from torch.nn.utils.rnn import pad_sequence
        
        # Feature extractor (excluding the final fc layer)
        net = self.net.rnn
        m = int(self.num_exemplars / self.num_classes)      # Number of exemplars per class
        
        # Enable Debug
        try:
            net.set_debug(0)
        except:
            pass
        
        # Assign methods to be used
        get_batch_data = self.train_func.get_batch_data
        
        with torch.no_grad():
            # Set Network Properties
            net = net.eval()

            dataset = self.dataloader.train_set
            # print('class_sizes = ', dataset.class_sizes)
            
            # Relative start index for current class for feature_lengths/target_lengths/feature_slices/target_slices/flags
            start_idx = 0
            
            y_high = self.num_new_classes
            # Add _silence_ keyword for the first task
            if self.num_learned_classes == 0:
                y_high += 1
            
            for y in tqdm(range(y_high), desc='ConstructExemplarSets'):
                class_idx = self.num_learned_classes + self.num_new_classes - y
                
                # Number of samples of the current class
                class_size = dataset.class_sizes[y]
                end_idx = start_idx + class_size
                
                indices = np.arange(start_idx, end_idx)
                dataloader = self.dataloader.subset_dataloader('train', indices, self.batch_size_eval)
                
                phi = []
                
                for batch_origin in dataloader:
                
                    batch = copy.deepcopy(batch_origin)
                    del batch_origin

                    # Get Batch Data
                    dict_batch_tensor = get_batch_data(self, batch)
                    # print(dict_batch_tensor['indices'].data)
                    # (Nt, Nb, num_features)
                    features_in = dict_batch_tensor['features']
                    device = features_in.device
                    feature_lengths = dict_batch_tensor['feature_lengths'].to(device)
                    targets = dict_batch_tensor['targets'].to(device)   # (Nb, Nt)
                    flags = dict_batch_tensor['flags']
                    assert (flags == class_idx).all()

                    net.flatten_parameters()
                    # (Nt, Nb, Nh)
                    features_out = net(features_in)[0].detach()

                    # (Nt, Nb)
                    # mask = util.length_to_mask(feature_lengths, batch_first=False, dtype=torch.bool)
                    # mask = mask.unsqueeze(2)
                    # features_out = torch.masked_fill(features_out, ~mask, 0)
                    
                    # Average along time axis as the output feature (phi) of each sequence
                    # (Nb, Nh)
                    # phi_batch = torch.mean(features_out, dim=0)
                    
                    # nz_idx_batch = [
                    #     torch.nonzero(targets[i, :])
                    #     for i in range(targets.size()[0])
                    # ]
                    # last_nz_idx_batch = [
                    #     torch.amax(nz_idx, dim=1) if nz_idx.size()[0] > 0 else targets.size()[1]-1
                    #     for nz_idx in nz_idx_batch
                    # ]
                    # phi_batch = [
                    #     features_out[last_nz_idx_batch[i], i, :]
                    #     for i in range(features_out.size()[1])
                    # ]
                    phi_batch = [
                        features_out[feature_lengths[i]-1, i, :]
                        for i in range(features_out.size()[1])
                    ]
                    phi_batch = torch.stack(phi_batch)
                    
                    phi_batch = phi_batch / torch.linalg.norm(phi_batch, dim=1, keepdims=True)
                    phi.append(phi_batch.cpu().numpy())
                    
                    del dict_batch_tensor, features_out
                
                # (class_size, rnn_size)
                phi = np.concatenate(phi, axis=0)
                
                # Compute class means (mu)
                mu = np.mean(phi, axis=0)
                mu = mu / np.linalg.norm(mu)
                
                exemplar_i = []
                exemplar_set = []
                exemplar_features = []
                for k in range(m):
                    sum = np.sum(exemplar_features, axis=0)
                    mu_p = 1.0/(k+1) * (phi + sum)
                    mu_p = mu_p / np.linalg.norm(mu_p, axis=1, keepdims=True)
                    # dist.shape == (class_size,)
                    dist = np.sqrt(np.sum((mu - mu_p) ** 2, axis=1))
                    
                    # i = np.argmin(dist)
                    i_sorted = np.argsort(dist)
                    # Find the first index that is not already in the exemplar set
                    i = None
                    for i_temp in i_sorted:
                        if i_temp not in exemplar_i:
                            i = i_temp
                            break
                    # print(f"Class {class_idx}: idx {i} added to exemplar set, dist[i]={dist[i]}")
                    
                    exemplar_i.append(i)
                    # # Store input features into exemplar set
                    # exemplar_set.append(features_in[:feature_lengths[i], i, :])
                    # Store absolute index of input features into exemplar set
                    exemplar_set.append(dataset.start_idx_base + start_idx + i)
                    exemplar_features.append(phi[i, :])
                    
                    # phi = np.delete(phi, i, 0)
                    # features_in = np.delete(features_in, i, 0)
                
                # print(f"Class {class_idx} exemplar_set: {exemplar_set}")
                self.exemplar_sets[class_idx] = exemplar_set
                
                start_idx = end_idx
        
        # print(torch.cuda.memory_summary())
        # print(f"torch.cuda.memory_allocated = {torch.cuda.memory_allocated():,}")
        # print(f"torch.cuda.memory_reserved = {torch.cuda.memory_reserved():,}")
        # print(f"torch.cuda.max_memory_allocated = {torch.cuda.max_memory_allocated():,}")
        # print(f"torch.cuda.max_memory_reserved = {torch.cuda.max_memory_reserved():,}")
        
        return

    ############################################################################
    # Update Exemplar Sets Means (iCaRL)
    def update_exemplar_sets_means(self):
        from torch.nn.utils.rnn import pad_sequence
        
        self.exemplar_sets_means = torch.zeros((self.num_classes, self.rnn_size))
        
        # Feature extractor (excluding the final fc layer)
        net = self.net.rnn
        
        # Enable Debug
        try:
            net.set_debug(0)
        except:
            pass
        
        with torch.no_grad():
            # Set Network Properties
            net = net.eval()

            dataset = self.dataloader.train_set
            # print('class_sizes = ', dataset.class_sizes)
            
            # Relative start index of exemplar sets in trainset
            # start_idx = dataset.num_samples_origin
            
            for class_idx, idx_list in tqdm(self.exemplar_sets.items(), desc='UpdateExemplarSetMeans'):
                
                # Number of samples of the current class
                class_size = len(idx_list)
                # end_idx = start_idx + class_size
                # print(dataset.flags[start_idx:end_idx].unique().item())   # [20-0, 25-21, 30-26]
                
                feature_slices = [dataset.feature_slices_all[i] for i in idx_list]
                feature_lengths = [dataset.feature_lengths_all[i] for i in idx_list]
                flags = [dataset.flags_all[i] for i in idx_list]
                assert (np.array(flags) == class_idx).all()
                
                # List of input features of the current class
                features_in = [
                    dataset.features[
                        slice(feature_slices[i][0], feature_slices[i][1]), :
                    ] for i in range(class_size)
                ]
                
                # features_in.size() == (max_feature_length, class_size, num_features)
                features_in = pad_sequence(features_in)
                if self.use_cuda:
                    features_in = features_in.cuda()
                
                net.flatten_parameters()
                # features_out.size() == (max_feature_length, class_size, rnn_size)
                features_out = net(features_in)[0].detach()
                
                # Average along time axis as the output feature (phi) of each sequence
                # phi.size() == (class_size, rnn_size)
                # phi = torch.mean(features_out, dim=0)
                phi = [
                    # torch.mean(features_out[:feature_lengths[i], i, :], dim=0)
                    features_out[feature_lengths[i]-1, i, :]
                    for i in range(class_size)
                ]
                phi = torch.stack(phi)
                phi = phi / torch.linalg.norm(phi, dim=1, keepdims=True)
                
                # Compute class means (mu)
                mu_y = torch.mean(phi, dim=0)
                mu_y = mu_y / torch.linalg.norm(mu_y)
                
                # print(f"Class {class_idx} exemplar_set_mean: {mu_y}")
                self.exemplar_sets_means[class_idx] = mu_y
                
                # start_idx = end_idx
                del features_in, features_out

        return

    ############################################################################
    # Evaluation using means of exemplar sets (iCaRL)
    def eval_icarl(self, set_name):
        
        # Feature extractor (excluding the final fc layer)
        net = self.net.rnn
        
        # Disable Debug
        try:
            net.set_debug(0)
        except:
            pass
        
        # Assign methods to be used
        get_batch_data = self.train_func.get_batch_data
        
        total_samples = 0
        total_correct = 0
        
        with torch.no_grad():
            # Set Network Properties
            net = net.eval()
            
            # No shuffle
            dataloader = self.dataloader.dev_loader if set_name == 'dev' else self.dataloader.test_loader
            
            for batch_origin in tqdm(dataloader, desc='iCaRL_eval_'+set_name):

                batch = copy.deepcopy(batch_origin)
                del batch_origin

                # Get Batch Data
                dict_batch_tensor = get_batch_data(self, batch)
                # print(dict_batch_tensor['indices'].data)
                # (Nt, Nb, num_features)
                features_in = dict_batch_tensor['features']
                feature_lengths = dict_batch_tensor['feature_lengths']
                batch_size = features_in.size()[1]

                net.flatten_parameters()
                # (Nt, Nb, Nh)
                features_out = net(features_in)[0].detach()
                
                # Average along time axis as the output feature (phi) of each sequence
                # (Nb, Nh)
                phi = [
                    # torch.mean(features_out[:feature_lengths[i], i, :], dim=0)
                    features_out[feature_lengths[i]-1, i, :]
                    for i in range(batch_size)
                ]
                phi = torch.stack(phi)
                phi = phi / torch.linalg.norm(phi, dim=1, keepdims=True)
                
                # (Nc, Nh)
                mu_y = self.exemplar_sets_means
                if self.use_cuda:
                    mu_y = mu_y.cuda()
                
                # (Nb, Nh, Nc)
                phi = phi.unsqueeze(2).expand(-1, -1, self.num_classes)
                mu_y = mu_y.unsqueeze(2).expand(-1, -1, batch_size).transpose(0, 2)
                
                # (Nb, Nc)
                dist = (phi - mu_y).pow(2).sum(dim=1)
                y_pred = torch.argmin(dist, dim=1)
                
                y_true = dict_batch_tensor['flags']
                if self.use_cuda:
                    y_true = y_true.cuda()
                
                total_samples += batch_size
                total_correct += torch.count_nonzero(y_pred == y_true)
                
                del dict_batch_tensor, features_out
        
        total_correct = total_correct.item()
        acc = total_correct / total_samples
        print(f"iCaRL-ACC-{set_name} = {total_correct:d} / {total_samples:d} = {acc:f}")
        
        import csv
        filename = 'exp_il.csv'
        # filename = self.logfile_hist.replace(".csv", "_il.txt")
        with open(filename, 'a', newline='') as csvfile:
            spamwriter = csv.writer(csvfile, delimiter=',')
            spamwriter.writerow([total_correct, total_samples])
        
        return
    
    ############################################################################
    # Save model
    def save_model(self):
        import pickle
        
        if self.il_save_model:
            pt_name = self.save_file
            torch.save(self.net.state_dict(), pt_name)
            print(f">>> Model saved to \"{pt_name}\"")
            
            pkl_name = self.save_file.replace('.pt', '.pkl')
            with open(pkl_name, 'wb') as fp:
                pickle.dump(self.exemplar_sets, fp)
                print(f">>> Exemplar sets saved to \"{pkl_name}\"")
                
        return

