include .config/make/config.mk

#==== RULES ====================================================================
#---- RELEASE ------------------------------------------------------------------

$(BIN)_release: $(OPT_OBJS)
	$(Q)$(MKDIR) $(BIN_DIR)
	$(Q)echo -e "====> LD $@"
	$(Q)$(CC) $(RELEASE) $+ -o $@ $(LDFLAGS)

$(BUILD_DIR)/%.opt.o: %.c
	$(Q)echo "====> CC $@"
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CC) $(RELEASE) $(CFLAGS) -c $< -o $@

release: $(BIN)_release

#---- DEBUGGING ----------------------------------------------------------------

$(BIN)_debugging: $(DBG_OBJS) 
	$(Q)$(MKDIR) $(BIN_DIR)
	$(Q)echo -e "====> LD $@"
	$(Q)$(CC) $(DEBUGGING) $+ -o $@ $(LDFLAGS)

$(BUILD_DIR)/%.dbg.o: %.c
	$(Q)echo "====> CC $@"
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CC) $(DEBUGGING) $(CFLAGS) -c $< -o $@

debugging: $(BIN)_debugging

#---- SANITIZED ----------------------------------------------------------------

$(BIN)_sanitized: $(SAN_OBJS) 
	$(Q)$(MKDIR) $(BIN_DIR)
	$(Q)echo -e "====> LD $@"
	$(Q)$(CC) $(SANITIZED) $+ -o $@ $(LDFLAGS)

$(BUILD_DIR)/%.san.o: %.c
	$(Q)echo "====> CC $@"
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CC) $(SANITIZED) $(CFLAGS) -c $< -o $@

sanitized: $(BIN)_sanitized

#---- PROFILING ----------------------------------------------------------------

$(BIN)_profiling: $(PROF_OBJS) 
	$(Q)$(MKDIR) $(BIN_DIR)
	$(Q)echo -e "====> LD $@"
	$(Q)$(CC) $(PROFILING) $+ -o $@ $(LDFLAGS) -pg

$(BUILD_DIR)/%.prof.o: %.c
	$(Q)echo "====> CC $@"
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CC) $(PROFILING) $(CFLAGS) -c $< -o $@

profiling: $(BIN)_profiling

#---- CLEANING -----------------------------------------------------------------

clean:
	$(Q)echo "====> Cleaning..."
	$(Q)$(RM) --recursive --force $(BUILD_DIR)/$(SRC_DIR)

#---- DOCUMENTATION ------------------------------------------------------------

docs:
	$(Q)echo "====> Creating the documentation..."
	$(Q)doxygen

#---- STYLE --------------------------------------------------------------------

style:
	$(Q)echo "====> Formatting..."
	$(Q)find $(SRC_DIR) -iname *.h -o -iname *.c | xargs clang-format -i $(CLANG_FMT_CONFIG)

#---- ANALYSIS -----------------------------------------------------------------

analyze:
	$(Q)$(MKDIR) logs
	$(Q)echo "====> Running scan-build..."
	$(Q)scan-build make all
	$(Q)echo "====> Running cppcheck..."
	$(Q)cppcheck src/ $(CPPCHECK) 2> logs/cppcheck.log
	$(Q)echo "====> Running clang-tidy..."
	$(Q)compiledb make all
	$(Q)clang-tidy.py $(PROJ_SRCS) $(CLANG_TIDY_CONFIG) || true
	$(Q)yq 'del(.Diagnostics[] | select(.DiagnosticMessage.FilePath | test("deps")))' tidy.log > logs/tidy.log
	$(Q)$(RM) tidy.log
	$(Q)scan-build $(MAKE)

memcheck: debugging
	$(Q)echo "====> Running memcheck..."
	$(Q)valgrind ${VALGRIND} $(BIN)_debugging

callgrind: debugging
	$(Q)echo "====> Running callgrind..."
	$(Q)valgrind ${CALLGRIND} $(BIN)_debugging

massif: debugging
	$(Q)echo "====> Running massif..."
	$(Q)valgrind ${massif} $(BIN)_debugging

dhat: debugging
	$(Q)echo "====> Running massif..."
	$(Q)valgrind ${dhat} $(BIN)_debugging

#---- INSTALLING ---------------------------------------------------------------

install: release
	$(Q)echo "====> Installing the binary..."
	$(Q)cp $(BIN)_release $(PREFIX)/bin/$(NAME)
	$(Q)echo "====> Installing the library..."
	$(Q)$(MKDIR) $(PREFIX)/lib/lispy
	$(Q)cp $(LIB)/stdlib.lspy $(PREFIX)/lib/lispy/
	$(Q)echo "====> Finished!"
	
uninstall:
	$(Q)echo "====> Removing the binary..."
	$(Q)$(RM) $(PREFIX)/bin/$(NAME)
	$(Q)echo "====> Removing the library..."
	$(Q)$(RM) $(PREFIX)/lib/lispy/stdlib.lspy
	$(Q)rmdir $(PREFIX)/lib/lispy/
	$(Q)echo "====> Finished!"

#==== EPILOGUE =================================================================

all: style release debugging sanitized profiling
	$(Q)echo "====> Finished!"

# Include the .d makefiles
-include $(DEPS)
.PHONY: all release debugging memcheck style install uninstall profiling docs
