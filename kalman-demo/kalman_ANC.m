clear
%close all

%% toy system parameters
w0 = [1,2,3,4,5,6,7,8,9,10];
S = diag([1, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55]);
V = 1;

%% initializing
wi = normrnd(0,1,[1 10]);
noise = normrnd(0,10,[80,10]);

w_log(1:81,1:10) = 0;
w_log(1,:) = wi;
e_log(1:80) = 0;

P = eye(10,10);

%% Kalman filter procedure
for i = 1:80
    xk = transpose(noise(i,:));
    desire = sum(S*(diag(w0)*xk));
    xk = S*xk;
    error = desire - wi*xk + normrnd(0,V*6);
    gain = P*xk./(transpose(xk)*P*xk + (1*V)^2) ;
    wi = wi + transpose(gain*error);
    P = P - gain*transpose(xk)*P;
    w_log(i+1,:) = wi;
    e_log(i) = (error/(w0*xk));
end

%% plot the result
figure
plot(w_log);
title('Updating the coefficients','FontSize',16)
xlabel('n','FontSize',16)
ylabel('W[n]','FontSize',16)
figure
plot(e_log);
title('Reletive Error','FontSize',16)
xlabel('n','FontSize',16)
ylabel('fraction(%)','FontSize',16)