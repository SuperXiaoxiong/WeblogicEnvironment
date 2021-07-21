# 基础镜像
FROM centos
# 参数
ARG JDK_PKG
ARG WEBLOGIC_JAR
ARG PATCH_PKG
# 解决libnsl包丢失的问题
RUN yum -y install psmisc && yum -y install libnsl 

# 创建用户
RUN groupadd -g 1000 oinstall && useradd -u 1100 -g oinstall oracle
# 创建需要的文件夹和环境变量
RUN mkdir -p /install && mkdir -p /scriptsi && mkdir opatch_dir
ENV JDK_PKG=$JDK_PKG
ENV WEBLOGIC_JAR=$WEBLOGIC_JAR
ENV PATCH_PKG=$PATCH_PKG

# 复制脚本
COPY scripts/jdk_install.sh /scripts/jdk_install.sh 
COPY scripts/jdk_bin_install.sh /scripts/jdk_bin_install.sh 

COPY scripts/weblogic_install11g.sh /scripts/weblogic_install11g.sh
COPY scripts/weblogic_install12c.sh /scripts/weblogic_install12c.sh
COPY scripts/create_domain11g.sh /scripts/create_domain11g.sh
COPY scripts/create_domain12c.sh /scripts/create_domain12c.sh
COPY scripts/open_debug_mode.sh /scripts/open_debug_mode.sh
COPY jdks/$JDK_PKG .
COPY weblogics/$WEBLOGIC_JAR .
COPY opatch/opatch_generic.jar .
COPY patch_dir/$PATCH_PKG /opatch_dir/$PATCH_PKG/


# 判断jdk是包（bin/tar.gz）weblogic包（11g/12c）载入对应脚本
RUN if [ $JDK_PKG == *.bin ] ; then echo ****载入JDK bin安装脚本**** && cp /scripts/jdk_bin_install.sh /scripts/jdk_install.sh ; else echo ****载入JDK tar.gz安装脚本**** ; fi
RUN if [ $WEBLOGIC_JAR == *1036* ] ; then echo ****载入11g安装脚本**** && cp /scripts/weblogic_install11g.sh /scripts/weblogic_install.sh && cp /scripts/create_domain11g.sh /scripts/create_domain.sh ; else echo ****载入12c安装脚本**** && cp /scripts/weblogic_install12c.sh /scripts/weblogic_install.sh && cp /scripts/create_domain12c.sh /scripts/create_domain.sh  ; fi

# 脚本设置权限及运行
RUN chmod +x /scripts/jdk_install.sh
RUN chmod +x /scripts/weblogic_install.sh
RUN chmod +x /scripts/create_domain.sh
RUN chmod +x /scripts/open_debug_mode.sh
# 安装JDK
RUN /scripts/jdk_install.sh
# 安装weblogic
RUN /scripts/weblogic_install.sh
# 创建Weblogic Domain
RUN /scripts/create_domain.sh
# 打开Debug模式
RUN /scripts/open_debug_mode.sh
# 启动 Weblogic Server
# CMD ["tail","-f","/dev/null"]

RUN chmod -R 777 /opatch_dir
USER oracle
# opatch 限制非 root 用户运行
RUN /java/bin/java -jar opatch_generic.jar -silent oracle_home=/u01/app/oracle/middleware
# 更新opatch
WORKDIR /opatch_dir/$PATCH_PKG
RUN /u01/app/oracle/middleware/OPatch/opatch apply -silent
# 更新weblogic-server

USER root
RUN rm  -rf /var/lib/apt/lists/*
CMD ["/u01/app/oracle/Domains/ExampleSilentWTDomain/bin/startWebLogic.sh"]
EXPOSE 7001
