clear;
clc,close all;
ori_path='/media/vim/941bfed3-dbb1-4e73-80a7-a5601b4f9505/Wangweiwei/weiwei/TMC/MPEG_CTC/Cat1_A/';
rec_base_path='/media/vim/941bfed3-dbb1-4e73-80a7-a5601b4f9505/Wangweiwei/weiwei/TMC/compress_code/V9.0/cfg/octree-predlift/lossless-geom-lossy-attrs/';
h5_train='/media/vim/941bfed3-dbb1-4e73-80a7-a5601b4f9505/Wangweiwei/weiwei/pointcloud/code/Enhancement_MPEG/data/TrainData/r06/train/';
h5_test='/media/vim/941bfed3-dbb1-4e73-80a7-a5601b4f9505/Wangweiwei/weiwei/pointcloud/code/Enhancement_MPEG/data/TrainData/r06/test/';
txt_path='/media/vim/941bfed3-dbb1-4e73-80a7-a5601b4f9505/Wangweiwei/weiwei/TMC/MPEG_CTC/Cat1_A/trainFile.txt';
file=importdata(txt_path);
% sequences=dir([ori_path,'*.ply']);
sequence_number=length(file);
h1=waitbar(0,'read from sequences...');
for i=1:sequence_number 
    str1=['reading sequences...',num2str(i/sequence_number),'%'];
    waitbar( i/sequence_number,h1,str1);
    % ori_name=sequences(i).name;
    ori_name=file{i};
    fprintf('The %d -th sequence：%s \n',i,ori_name);
    ori_onlyName=ori_name(1:end-4);
    % tempSplit=strsplit(ori_onlyName,'_');
    rec_onlyName=[ori_onlyName,'_rec'];
    % rec_onlyName=[ori_onlyName,'_rec-',tempSplit{end}];
    ori=pcread([ori_path,ori_name]);
    ori_loc=ori.Location;
    ori_color=ori.Color;
    pointNumber=length(ori_loc);
    num_Sample=round(pointNumber/1024);
    train_sample=round(num_Sample*0.8);
    test_sample=num_Sample-train_sample;
    rec_path=[rec_base_path,ori_onlyName,'/r06/reconstruct/'];
    rec=pcread([rec_path,rec_onlyName,'.ply']);
    rec_color=rec.Color;
    rec_loc=rec.Location;
    h5create([h5_train,ori_onlyName,'.h5'],'/data',[1024,3,train_sample]);
    h5create([h5_train,ori_onlyName,'.h5'],'/label',[1024,3,train_sample]);
    h5create([h5_test,ori_onlyName,'.h5'],'/data',[1024,3,test_sample]);
    h5create([h5_test,ori_onlyName,'.h5'],'/label',[1024,3,test_sample]);
    box_label_train=zeros(1024,3,train_sample);
    box_data_train=zeros(1024,3,train_sample);
    box_label_test=zeros(1024,3,test_sample);
    box_data_test=zeros(1024,3,test_sample);     % placeholder for all the data
    centroids_ori=FPS(ori_loc,num_Sample);                        %FPS algorithm select the index of the represent point
    h2=waitbar(0,'match the data');
    kdtreeObj_ori=KDTreeSearcher(ori_loc,'distance','euclidean');             % build the object for kdtree
    centroid_loc=ori_loc(centroids_ori,:);
    [idxnn_ori,dis]=knnsearch(kdtreeObj_ori,centroid_loc,'k',1024);   % 索引按照距离centroid的由小到大的顺序排列,[num_sample,1024]
    kdtreeObj_rec=KDTreeSearcher(rec_loc,'distance','euclidean');
    f=1;
    for j=1:num_Sample
        str2=['matching...',num2str(j/num_Sample),'%'];
        waitbar(j/num_Sample,h2,str2);
        curPatchIdx_ori=idxnn_ori(j,:);        % 1024
        curPatchLoc_ori=ori_loc(curPatchIdx_ori,:);
        curPatchCol_ori=ori_color(curPatchIdx_ori,:);
        [idx_rec,dis_rec]=knnsearch(kdtreeObj_rec,curPatchLoc_ori,'k',1);    % corresponding idx in reconstruction point cloud in the same patch with the original pt
        curPatchLoc_rec=rec_loc(idx_rec,:);
        curPatchCol_rec=rec_color(idx_rec,:);
        if(curPatchLoc_ori~=curPatchLoc_rec)
            error('rec not equal to ori when doing train dataset');
        end
        if(j<=train_sample)
             box_label_train(:,:,j)=curPatchCol_ori;
             box_data_train(:,:,j)=curPatchCol_rec;
        else
            box_label_test(:,:,f)=curPatchCol_ori;
            box_data_test(:,:,f)=curPatchCol_rec; 
            f=f+1;
        end
       
    end
    close(h2);
    clear f;
    h5write([h5_train,ori_onlyName,'.h5'],'/data',box_data_train);
    h5write([h5_train,ori_onlyName,'.h5'],'/label',box_label_train);
    h5write([h5_test,ori_onlyName,'.h5'],'/data',box_data_test);
    h5write([h5_test,ori_onlyName,'.h5'],'/label',box_label_test);
end
close(h1);