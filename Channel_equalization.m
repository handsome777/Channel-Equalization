clear;
clc;
train_num = 535;    %��Ϊ������Ǵ�L��train_num���е��������Գ���Ϊ500+L
test_num_init = 5035;
SNR_init = 30;
e = 1e-6;
mu = 0.4;           %NLMS��mu
mu1 = 0.0015;       %LMS��mu
L = 35;             %����������
deta = 15;          %��ʱ
if_LMS = 1;         %1 = LMS; 0 = NLMS
q = 2;              %1=��һ�ʣ�2=�ڶ��ʣ�3=�����ʣ�4=������

%filter parameters
a = 1;
b = [0.5,1,1.2,-1,0];

C = zeros(1,L);

if q == 1                                           %��һ��
    mode = 16;                                      %�����ģʽΪ16-QAM
    if_LMS = 0;                                     %ʹ��NLMS
    C = train_process(b, a, train_num,SNR_init,...  %����ѵ��
        L,C, deta, mu, mu1,e, if_LMS);
    test_num = test_num_init;
    test_id = get_test_id(mode);                    %�õ�����ģʽ�����п��ܷ���
    
    [acc_bad, test_x, test_u, C, jd] = ...          %���в���
        test_process(b, a, mode,test_num, SNR_init,...
        L,C, test_id, deta, mu, mu1, e, if_LMS);
    plot_s_u_s_hat(test_x, test_u, jd);             %����s(i),u(i),s_hat(i)
    
elseif q == 2                                       %��2��
    mode = 16;                                      %����16QAM
    test_id = get_test_id(mode);
    test_num = test_num_init;
    iteration_num = [150,300,500];             %��������
    %iteration_num = [300];
    for i = iteration_num
        %NLMS
        C = zeros(1,L);                             %��ʼ��������ϵ��
        if_LMS = 0;
        C = train_process(b, a, i+L,SNR_init,L,C, deta, mu, mu1,e, if_LMS);
        [~, test_x, test_u, C, jd] = test_process(b, a, mode,...
                test_num, SNR_init,L,C, test_id, deta, mu, mu1, e, if_LMS);
        plot_s_u_s_hat(test_x, test_u, jd);
        %LMS
        C = zeros(1,L);                             %��ʼ��������ϵ��
        if_LMS = 1;
        C = train_process(b, a, i+L,SNR_init,L,C, deta, mu, mu1,e, if_LMS);
        [~, test_x, test_u, C, jd] = test_process(b, a, mode,...
                test_num, SNR_init,L,C, test_id, deta, mu, mu1, e, if_LMS);
        plot_s_u_s_hat(test_x, test_u, jd);
        pause();                                    %ÿ����һ�Σ���ͣһ�£��Թ��������
    end
    
    
elseif q == 3                                       %��3��
    mode = 256;                                     %ģʽΪ256-QAM
    test_id = get_test_id(mode);
    C = zeros(1,L);
    if_LMS = 0;
    C = train_process(b, a, train_num ,SNR_init,L,C, deta, mu, mu1,e, if_LMS);
    [~, test_x, test_u, C, jd] = test_process(b, a, mode,...
                test_num_init, SNR_init,L,C, test_id, deta, mu, mu1, e, if_LMS);
    plot_s_u_s_hat(test_x, test_u, jd);
    
elseif q == 4
    figure;
    hold on;
    title("SER-SNR");
    for mode = [4,16,64,256]
        mode
        test_num = 100000;
        test_id = get_test_id(mode);
        C = zeros(1,L);
        if_LMS = 0;
        C = train_process(b, a, train_num*3 ,SNR_init,L,C, deta, mu, mu1,e, if_LMS);
        C_init = C;                         %�����ʼ��ѵ���ľ�����ϵ������ÿһ��SNR�տ�ʼ������ʱ��ֵ
        SER = zeros(26,1);
        count = 1;                          %�ڼ���SNR   
        for SNR = 5:1:30
            C = C_init;                     %����ֵ��ѵ�������
            flag = 0;
            acc_bad = 0;
            while(acc_bad == 0)             %��û���о��������ʱ��һֱѭ��
                if flag == 1                %���û��û���о����������Ӳ��Գ���
                    test_num = test_num + 200000;
                end
                if test_num > 1500000       %������ȴ���150W������Ϊû�д�������ѭ��
                    break
                end
                [acc_bad, test_x, test_u, C, jd] = test_process(b, a, mode,...
                    test_num, SNR,L,C, test_id, deta, mu, mu1, e, if_LMS);
                if acc_bad == 0
                    flag = 1;               %���û�г��ִ�����ֵflagΪ1
                end
            end
            if acc_bad == 0
                break
            end
            test_num - L + 1;
            SER(count) = acc_bad * 1.0 / (test_num - L + 1);%����SER
            count = count + 1;
        end
        SNR = 5:1:30;
        %plot_s_u_s_hat(test_x, test_u, jd);


        semilogy(SNR,SER);
        xlabel("SNR");
        ylabel("SER");
        
    end
    legend("4-QAM","16-QAM","64-QAM","256-QAM");
end

%ѵ������
function C = train_process(b, a, train_num,SNR,L,C, deta, mu, mu1, e, if_LMS)
    %train data
    train_a = unidrnd(4,[1,train_num]) - 1;
    train_x = pskmod(train_a,4);%QPSK����
    [train_t, zf] = filter(b,a,train_x);
    train_u = awgn(train_t, SNR, 'measured');
    
    %training
    for i = L : 1 : train_num
        x = train_u(i:-1:i-L+1);
        ak = train_x(i-deta);
        yk = conj(C)*x.';
        ek = ak - yk;
        if if_LMS == 1
            delt = mu1 * conj(ek) * x;
        else
            delt = mu * conj(ek) * x / (e + sum(abs(x).^2));
        end
        C = C + delt;
    end
end

%�о�����
function ak = judge(yk, id)
    dis = abs(yk - id);
    [v, ind] = min(dis);
    ak = id(ind);
end

%�����ģʽ���п��ܵķ���
function id = get_id(x)
    temp = [];
    for i = 1:1:length(x)
        if ismember(x(i), temp)
            continue
        else
            temp = [temp, x(i)];
        end
    end
    id = temp;
end

%����ģʽ
function [acc_bad, test_x, test_u,C, jd] = test_process(b,a, mode,...
    test_num,SNR,L,C, test_id, deta, mu, mu1, e,if_LMS)
    acc_bad_ = 0;
    test_x = unidrnd(mode,[1,test_num]) - 1;
    test_x = qammod(test_x, mode);
    [test_t, zf] = filter(b,a,test_x);
    %test_t = conv(test_x,[0.5,1,1.2,-1]);
    test_u = awgn(test_t, SNR, 'measured');

    jd = zeros(test_num,1);
    for i = L:1:test_num
        x = test_u(i:-1:i-L+1);
        yk = conj(C)*x.';
        jd(i) = yk;
        ak = judge(jd(i), test_id);
        if ak ~= test_x(i-deta)
            acc_bad_ = acc_bad_ + 1;
        end
        ek = ak - yk;
        if if_LMS == 1
            delt = mu1 * conj(ek) * x;
        else
            delt = mu * conj(ek) * x / (e + sum(abs(x).^2));
            C = C + delt;
        end
        
    end
    acc_bad = acc_bad_;
end

%����s(i),u(i),s_hat(i)��ɢ��ͼ
function plot_s_u_s_hat(s, u, s_hat)
%scatter the s(i)
scatterplot(s);
title("S(i)");

%scatter the u(i)
scatterplot(u);
title("U(i)");

%scatter the s_hat(i)
scatterplot(s_hat);
title("S_{hat}(i-delta)");
end

%����get_id�������õ�test�����п��ܷ���
function test_id = get_test_id(mode)
    id_ = unidrnd(mode,[1,10000]) - 1;
    id_ = qammod(id_, mode);
    test_id = get_id(id_);
end


