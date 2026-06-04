classdef ChannelModel < handle

    properties
        pathLossExponent
        gainMap
    end

    methods
        %========== 생성자 ==========
        function obj = ChannelModel(pathLossExponent)
            obj.pathLossExponent = pathLossExponent;
            obj.gainMap = containers.Map();
        end

        %========== 슬롯마다 채널 이득 갱신 ==========
        function update(obj, txNodes, rxNodes, jammer)
            obj.gainMap = containers.Map();

            N = length(txNodes);

            %========== Tx/Rx 사용자 링크 및 간섭 링크 ==========
            for txIdx = 1:N
                for rxIdx = 1:N
                    txNode = txNodes{txIdx};
                    rxNode = rxNodes{rxIdx};

                    gain = obj.generateGain(txNode.position, rxNode.position);

                    % DATA 방향: Tx_i -> Rx_j
                    keyData = obj.makeKey( ...
                        txNode.role, txNode.id, ...
                        rxNode.role, rxNode.id ...
                    );
                    obj.gainMap(keyData) = gain;

                    % ACK/역방향: Rx_j -> Tx_i
                    % 같은 슬롯에서는 reciprocal channel로 동일 gain 사용
                    keyReverse = obj.makeKey( ...
                        rxNode.role, rxNode.id, ...
                        txNode.role, txNode.id ...
                    );
                    obj.gainMap(keyReverse) = gain;
                end
            end

            %========== Jammer -> Tx/Rx 링크 ==========
            for n = 1:N
                txNode = txNodes{n};
                rxNode = rxNodes{n};
            
                % Jammer -> Tx_n
                jammerToTxGain = obj.generateGain(jammer.position, txNode.position);
            
                keyJammerToTx = obj.makeKey( ...
                    jammer.role, jammer.id, ...
                    txNode.role, txNode.id ...
                );
            
                obj.gainMap(keyJammerToTx) = jammerToTxGain;
            
                % Jammer -> Rx_n
                jammerToRxGain = obj.generateGain(jammer.position, rxNode.position);
            
                keyJammerToRx = obj.makeKey( ...
                    jammer.role, jammer.id, ...
                    rxNode.role, rxNode.id ...
                );
            
                obj.gainMap(keyJammerToRx) = jammerToRxGain;
            end
        end

        %========== 채널 이득 가져오기 ==========
        function gain = getGain(obj, txRole, txId, rxRole, rxId)
            key = obj.makeKey(txRole, txId, rxRole, rxId);

            if isKey(obj.gainMap, key)
                gain = obj.gainMap(key);
            else
                gain = 0;
            end
        end

        %========== 링크 key 생성 ==========
        function key = makeKey(obj, txRole, txId, rxRole, rxId)
            key = sprintf("%s%d_%s%d", ...
                string(txRole), txId, ...
                string(rxRole), rxId);
        end

        %========== 채널 이득 생성 ==========
        function gain = generateGain(obj, txPosition, rxPosition)
            distance = norm(txPosition - rxPosition);
            distance = max(distance, 1);

            % Large-scale fading: d^(-mu)
            largeScaleFading = distance^(-obj.pathLossExponent);

            % Small-scale fading: Rayleigh power gain
            h = (randn + 1i * randn) / sqrt(2);
            smallScaleFading = abs(h)^2;
            % smallScaleFading = 1;

            % Channel gain: g = d^(-mu) * |h|^2
            gain = largeScaleFading * smallScaleFading;
        end
    end
end