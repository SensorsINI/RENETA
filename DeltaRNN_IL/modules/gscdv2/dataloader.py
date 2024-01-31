__author__ = "Chang Gao"
__copyright__ = "Copyright @ Chang Gao"
__credits__ = ["Chang Gao"]
__license__ = "Private"
__version__ = "0.0.1"
__maintainer__ = "Chang Gao"
__email__ = "gaochangw@outlook.com"
__status__ = "Prototype"

import os

import h5py
import numpy as np

from utils import util
from utils.util import load_h5py_data, quantize_array
import torch
from torch.utils import data
from torch.nn.utils.rnn import pad_sequence
from project import Project
from typing import Sequence


class DataLoader:
    def __init__(self, proj: Project):
        # Get Arguments
        batch_size = proj.batch_size
        batch_size_test = proj.batch_size_eval

        # Create Datasets
        # No validation set in il_mode
        train_set = GSCDDataset(proj, proj.trainfile)
        # dev_set = GSCDDataset(proj, proj.devfile)
        test_set = GSCDDataset(proj, proj.testfile)
        self.num_features = test_set.num_features

        # Check Number of Classes
        num_classes = proj.num_classes
        if proj.loss == 'ctc':
            num_classes += 1  # CTC Label Shift
            proj.additem('num_classes', num_classes)

        train_set, train_set_stat = process_train(proj, train_set)
        # dev_set, dev_set_stat = process_test(proj, dev_set, train_set_stat)
        dev_set, dev_set_stat = train_set, train_set_stat
        test_set, test_set_stat = process_test(proj, test_set, train_set_stat)
        
        self.train_set = train_set

        # Define Collate Function
        def collate_fn(data):
            """
                data: is a list of tuples with (example, label, length)
                        where 'example' is a tensor of arbitrary shape
                        and label/length are scalars
            """
            feature, feature_length, target, target_length, flag, index = zip(*data)
            feature_lengths = torch.stack(feature_length).long()
            target_lengths = torch.stack(target_length).long()
            flags = torch.stack(flag).long()
            features = pad_sequence(feature)                    # (Nt, Nb, Nf)  Nf==num_features
            targets = pad_sequence(target, batch_first=True)    # (Nb, Nt)
            indices = torch.tensor(index).long()
            return features, feature_lengths, targets, target_lengths, flags, indices

        # Create PyTorch dataloaders for train and test set
        num_workers = int(proj.num_cpu_threads / 4)
        self.num_workers = num_workers
        self.train_loader = data.DataLoader(dataset=train_set, batch_size=batch_size, shuffle=True,
                                            num_workers=num_workers, collate_fn=collate_fn)
        self.dev_loader = data.DataLoader(dataset=dev_set, batch_size=batch_size_test, shuffle=False,
                                          num_workers=num_workers, collate_fn=collate_fn)
        self.test_loader = data.DataLoader(dataset=test_set, batch_size=batch_size_test, shuffle=False,
                                           num_workers=num_workers, collate_fn=collate_fn)
        self.collate_fn = collate_fn

    # Create custom dataloader for subset of dataset
    def subset_dataloader(self, set, indices: Sequence[int], batch_size=1, shuffle=False):
        if set == 'train':
            dataset = self.train_set
        else:
            raise NotImplementedError
        subset = data.Subset(dataset, indices)
        dataloader = data.DataLoader(dataset=subset, batch_size=batch_size, shuffle=shuffle,
                                     num_workers=self.num_workers, collate_fn=self.collate_fn)
        return dataloader


class GSCDDataset(data.Dataset):
    def __init__(self, proj: Project,
                 feat_path: str):
        """
        param name: 'train', 'dev' or 'test'
        """
        # Load data
        with h5py.File(feat_path, 'r') as hf:
            # # Load H5PY Data
            # dict_data = load_h5py_data(hf)
            # self.features = dict_data['features'].astype(np.float32)
            # self.feature_lengths = dict_data['feature_lengths'].astype(int)
            # self.targets = np.squeeze(dict_data['targets'].astype(int))
            # self.target_lengths = dict_data['target_lengths'].astype(int)
            # self.flags = dict_data['flag'].astype(int)
            # self.num_features = int(dict_data['n_features'].astype(int))
            # self.num_classes = int(dict_data['n_classes'].astype(int))
            # self.stat = {}
            # self.num_samples = len(self.feature_lengths)
            # self.feature_slices = idx_to_slice(self.feature_lengths)
            # self.target_slices = idx_to_slice(self.target_lengths)

            # Load H5PY Data
            dict_data = load_h5py_data(hf)
            # flags_all == [35, ..., 35, 34, ..., 34, ...... , 1, ..., 1, 0, ..., 0] for trainset
            # flags_all == [35, ..., 35, 34, ..., 34, ...... , 1, ..., 1]            for testset
            flags_all = dict_data['flag'].astype(int)
            num_samples_all = len(flags_all)
            
            class_heads_all = np.where(np.roll(flags_all,1) != flags_all)[0]
            # print('class_heads_all =', class_heads_all)
            class_low = proj.num_learned_classes
            class_high = proj.num_learned_classes + proj.num_new_classes
            if 'TRAIN' in feat_path:
                # Trainset has _silence_ keyword (label == 0)
                start_idx = class_heads_all[-1-class_high]
                if proj.num_learned_classes == 0:
                    end_idx = num_samples_all
                    class_heads = class_heads_all[-1-class_high:]
                else:
                    end_idx = class_heads_all[-1-class_low] # excluding
                    class_heads = class_heads_all[-1-class_high:-1-class_low]
            else:
                # Testset does not have _silence_ keyword
                start_idx = class_heads_all[-class_high]
                # Testset contains all old classes
                end_idx = num_samples_all
                class_heads = class_heads_all[-class_high:]
            # print(start_idx, end_idx)
            class_heads = np.append(class_heads, end_idx)
            self.class_sizes = class_heads[1:] - class_heads[:-1]
            # class_heads_all = np.append(class_heads_all, num_samples_all)
            # class_sizes_all = class_heads_all[1:] - class_heads_all[:-1]
            # print('class_sizes_all =', class_sizes_all)
            self.start_idx_base = start_idx
            self.end_idx_base = end_idx
            
            self.num_features = dict_data['n_features'].astype(int)
            # self.num_classes = dict_data['n_classes'].astype(int)
            self.num_classes = proj.num_learned_classes + proj.num_new_classes + 1
            
            self.flags = flags_all[start_idx:end_idx]
            feature_lengths_all = dict_data['feature_lengths'].astype(int)
            target_lengths_all = dict_data['target_lengths'].astype(int)
            self.feature_lengths = feature_lengths_all[start_idx:end_idx]
            self.target_lengths = target_lengths_all[start_idx:end_idx]
            self.stat = {}
            self.max_feature_length_all = np.amax(feature_lengths_all)
            self.num_samples = end_idx - start_idx
            feature_slices_all = idx_to_slice(feature_lengths_all)
            target_slices_all = idx_to_slice(target_lengths_all)
            self.feature_slices = feature_slices_all[start_idx:end_idx]
            self.target_slices = target_slices_all[start_idx:end_idx]
            
            self.features = dict_data['features'].astype(np.float32)
            self.targets = np.squeeze(dict_data['targets'].astype(int))
            
            self.num_samples_all = num_samples_all
            self.feature_lengths_all = feature_lengths_all
            self.target_lengths_all = target_lengths_all
            self.feature_slices_all = feature_slices_all
            self.target_slices_all = target_slices_all
            self.flags_all = flags_all
            
            # Numpy Arrays to PyTorch Tensors
            self.features = torch.tensor(self.features).float()
            self.feature_lengths = torch.tensor(self.feature_lengths).long()
            self.targets = torch.tensor(self.targets).long()
            self.target_lengths = torch.tensor(self.target_lengths).long()
            self.flags = torch.tensor(self.flags).long()
            
        ### debug ###
        # print('--------', feat_path, '--------')
        # print(self.targets)
        # # print('targets unique:', self.targets.unique())
        # print(self.feature_lengths)
        # # print('feature_lengths unique:', self.feature_lengths.unique())
        # print(self.target_lengths)
        # # print('target_lengths unique:', self.target_lengths.unique())
        # print(self.num_features)
        # print(self.num_classes)
        # print(self.num_samples)
        # print(len(self.feature_slices))
        # print(len(self.target_slices))
        # print(self.flags)
        # assert False
        
        # Update arguments
        if 'TRAIN' in feat_path:
            proj.additem('input_size', self.num_features)
            proj.additem('num_classes', self.num_classes)
            self.num_samples_origin = self.num_samples      # Excluding exemplar sets

    def __len__(self):
        'Total number of samples'
        return self.num_samples  # The first dimention of the data tensor

    def __getitem__(self, idx):
        'Get one sample from the dataset using an index'
        # Complete dataset (use absolute index):
        #     features, targets
        # Partial dataset (use relative index):
        #     feature_lengths, target_lengths
        #     feature_slices, target_slices (store absolute indices of features/targets)
        #     flags
        feature = self.features[slc(idx, self.feature_slices), :]
        feature_length = self.feature_lengths[idx]
        target = self.targets[slc(idx, self.target_slices)]
        target_length = self.target_lengths[idx]
        flag = self.flags[idx]

        return feature, feature_length, target, target_length, flag, idx
    
    # Add items existing in features/targets
    #   into feature_lengths/target_lengths/feature_slices/target_slices/flags
    #   according to a list of absolute indices
    def re_add_items(self, idx_list):
        # assert 0 <= idx < self.num_samples_all
        feature_lengths_new = torch.tensor([self.feature_lengths_all[i] for i in idx_list]).long()
        target_lengths_new = torch.tensor([self.target_lengths_all[i] for i in idx_list]).long()
        feature_slices_new = [self.feature_slices_all[i] for i in idx_list]
        target_slices_new = [self.target_slices_all[i] for i in idx_list]
        flags_new = torch.tensor([self.flags_all[i] for i in idx_list]).long()
        
        self.feature_lengths = torch.cat((self.feature_lengths, feature_lengths_new), dim=0)
        self.target_lengths = torch.cat((self.target_lengths, target_lengths_new), dim=0)
        self.feature_slices = self.feature_slices + feature_slices_new
        self.target_slices = self.target_slices + target_slices_new
        self.flags = torch.cat((self.flags, flags_new), dim=0)
        
        self.num_samples += len(idx_list)


def slc(idx, slices):
    return slice(slices[idx][0], slices[idx][1])


def log_lut(x, qi_in, qf_in, qi_out, qf_out, en, approx):
    if en:
        if approx:
            lut_in = quantize_array(x, qi_in, qf_in, 1)
            lut_out = np.log10(lut_in + 1)
            lut_out = quantize_array(lut_out, qi_out, qf_out, 1)
        else:
            lut_out = np.log10(1 + x)
        return lut_out
    else:
        return x


def quantize_feature(features, pre_max, fqi, fqf, en):
    if en:
        max_dynamic = 2 ** (fqi - 1)
        # Map Features to [0, 1]
        features /= pre_max
        # Scale Features to max dynamic range
        features = np.floor(features * max_dynamic)  # correct
        features = quantize_array(features, fqi, fqf, 1)
    return features


def process_train(proj: Project, train_set):
    stat = {'pre_mean_feat': torch.mean(train_set.features.view(-1, train_set.num_features), dim=0),
            'pre_std_feat': torch.std(train_set.features.view(-1, train_set.num_features), dim=0),
            'pre_max_feat': torch.amax(train_set.features.view(-1, train_set.num_features), dim=0),
            'pre_min_feat': torch.amin(train_set.features.view(-1, train_set.num_features), dim=0),
            'pre_shape': train_set.features.shape,
            'pre_mean': torch.mean(train_set.features),
            'pre_std': torch.std(train_set.features),
            'pre_max': torch.amax(train_set.features),
            'pre_min': torch.amin(train_set.features),
            'pre_num_sample': train_set.features.size(0)}

    if proj.qf:
        train_set.features = quantize_feature(train_set.features, stat['pre_max'], proj.fqi, proj.fqf, proj.qf)
    if proj.logf == 'lut':
        train_set.features = log_lut(train_set.features, qi_in=proj.fqi, qf_in=proj.fqf, qi_out=3, qf_out=8,
                                     en=proj.log_feat, approx=proj.approx_log)

    stat['post_mean_feat'] = torch.mean(train_set.features.view(-1, train_set.num_features), dim=0)
    stat['post_std_feat'] = torch.std(train_set.features.view(-1, train_set.num_features), dim=0)
    stat['post_max_feat'] = torch.amax(train_set.features.view(-1, train_set.num_features), dim=0)
    stat['post_min_feat'] = torch.amin(train_set.features.view(-1, train_set.num_features), dim=0)
    stat['post_shape'] = train_set.features.shape
    stat['post_mean'] = torch.mean(train_set.features)
    stat['post_std'] = torch.std(train_set.features)
    stat['post_max'] = torch.amax(train_set.features)
    stat['post_min'] = torch.amin(train_set.features)
    stat['post_num_sample'] = train_set.features.size(0)

    if proj.norm_feat:
        train_set.features -= stat['post_mean']
        train_set.features /= stat['post_std']

    return train_set, stat


def process_test(proj: Project, test_set, train_set_stat):
    stat = {'pre_mean_feat': torch.mean(test_set.features.view(-1, test_set.num_features), dim=0),
            'pre_std_feat': torch.std(test_set.features.view(-1, test_set.num_features), dim=0),
            'pre_max_feat': torch.amax(test_set.features.view(-1, test_set.num_features), dim=0),
            'pre_min_feat': torch.amin(test_set.features.view(-1, test_set.num_features), dim=0),
            'pre_shape': test_set.features.shape,
            'pre_mean': torch.mean(test_set.features),
            'pre_std': torch.std(test_set.features),
            'pre_max': torch.amax(test_set.features),
            'pre_min': torch.amin(test_set.features),
            'pre_num_sample': test_set.features.size(0)}

    if proj.qf:
        test_set.features = quantize_feature(test_set.features, train_set_stat['pre_max'], proj.fqi, proj.fqf, proj.qf)
    if proj.logf == 'lut':
        test_set.features = log_lut(test_set.features, qi_in=proj.fqi, qf_in=proj.fqf, qi_out=3, qf_out=8,
                                    en=proj.log_feat, approx=proj.approx_log)

    stat['post_mean_feat'] = torch.mean(test_set.features.view(-1, test_set.num_features), dim=0)
    stat['post_std_feat'] = torch.std(test_set.features.view(-1, test_set.num_features), dim=0)
    stat['post_max_feat'] = torch.amax(test_set.features.view(-1, test_set.num_features), dim=0)
    stat['post_min_feat'] = torch.amin(test_set.features.view(-1, test_set.num_features), dim=0)
    stat['post_shape'] = test_set.features.shape
    stat['post_mean'] = torch.mean(test_set.features)
    stat['post_std'] = torch.std(test_set.features)
    stat['post_max'] = torch.amax(test_set.features)
    stat['post_min'] = torch.amin(test_set.features)
    stat['post_num_sample'] = test_set.features.size(0)

    if proj.norm_feat:
        test_set.features -= train_set_stat['post_mean']
        test_set.features /= train_set_stat['post_std']

    return test_set, stat


def idx_to_slice(lengths):
    """
    Get the index range of samples
    :param lengths: 1-D tensor containing lengths in time of each sample
    :return: A list of tuples containing the start & end indices of each sample
    """
    idx = []
    lengths_cumsum = np.cumsum(lengths)
    for i, len in enumerate(lengths):
        start_idx = lengths_cumsum[i] - lengths[i]
        end_idx = lengths_cumsum[i]
        idx.append((start_idx, end_idx))
    return idx


